package com.myevcompanion.app.data

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

data class TeslaMateConnectionConfig(
    val baseUrl: String = "",
    val token: String = "",
    val useQueryToken: Boolean = false,
    val selectedCarId: Int? = null
) {
    val isConfigured: Boolean
        get() = baseUrl.trim().isNotEmpty() && token.trim().isNotEmpty()
}

data class TeslaMateCar(
    val id: Int,
    val name: String,
    val model: String?,
    val vin: String?
)

data class TeslaMateCharge(
    val id: Int,
    val startedAt: String?,
    val endedAt: String?,
    val energyKwh: Double?,
    val cost: Double?,
    val location: String?,
    val powerKw: Double?,
    val startSoc: Int?,
    val endSoc: Int?
)

data class TeslaMateDrive(
    val id: Int,
    val startedAt: String?,
    val endedAt: String?,
    val distance: Double?,
    val energyKwh: Double?,
    val cost: Double?,
    val efficiencyWhPerMile: Double?
)

data class TeslaMateStatus(
    val batteryLevel: Int?,
    val usableBatteryLevel: Int?,
    val chargingState: String?,
    val vehicleState: String?,
    val ratedRange: Double?,
    val idealRange: Double?,
    val locked: Boolean?,
    val sentryMode: Boolean?,
    val climateOn: Boolean?,
    val softwareVersion: String?
)

data class TeslaMateSnapshot(
    val cars: List<TeslaMateCar> = emptyList(),
    val status: TeslaMateStatus? = null,
    val charges: List<TeslaMateCharge> = emptyList(),
    val drives: List<TeslaMateDrive> = emptyList()
)

class TeslaMateConnectionStore(context: Context) {
    private val prefs = context.getSharedPreferences("teslamate_connection", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val _config = MutableStateFlow(
        TeslaMateConnectionConfig(
            baseUrl = prefs.getString("base_url", "").orEmpty(),
            token = prefs.getString("token", "").orEmpty(),
            useQueryToken = prefs.getBoolean("use_query_token", false),
            selectedCarId = prefs.getInt("selected_car_id", -1).takeIf { it >= 0 }
        )
    )
    val config: StateFlow<TeslaMateConnectionConfig> = _config

    private val _snapshot = MutableStateFlow(TeslaMateSnapshot())
    val snapshot: StateFlow<TeslaMateSnapshot> = _snapshot

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _message = MutableStateFlow("Add your TeslaMate API URL and token, then test the connection.")
    val message: StateFlow<String> = _message

    fun save(config: TeslaMateConnectionConfig) {
        val normalized = config.copy(baseUrl = config.baseUrl.trim().trimEnd('/'), token = config.token.trim())
        prefs.edit()
            .putString("base_url", normalized.baseUrl)
            .putString("token", normalized.token)
            .putBoolean("use_query_token", normalized.useQueryToken)
            .putInt("selected_car_id", normalized.selectedCarId ?: -1)
            .apply()
        _config.value = normalized
        _message.value = "TeslaMate connection saved."
    }

    fun clear() {
        prefs.edit().clear().apply()
        _config.value = TeslaMateConnectionConfig()
        _snapshot.value = TeslaMateSnapshot()
        _message.value = "TeslaMate connection cleared."
    }

    fun refresh() {
        val current = _config.value
        if (!current.isConfigured) {
            _message.value = "Add a TeslaMate API URL and token first."
            return
        }

        scope.launch {
            _isLoading.value = true
            runCatching {
                withContext(Dispatchers.IO) {
                    TeslaMateApiClient(current).fetchSnapshot()
                }
            }.onSuccess { snapshot ->
                _snapshot.value = snapshot
                val selected = snapshot.cars.firstOrNull { it.id == current.selectedCarId } ?: snapshot.cars.firstOrNull()
                if (selected != null && selected.id != current.selectedCarId) {
                    save(current.copy(selectedCarId = selected.id))
                }
                _message.value = "Loaded ${snapshot.cars.size} vehicle${if (snapshot.cars.size == 1) "" else "s"}, ${snapshot.charges.size} charge${if (snapshot.charges.size == 1) "" else "s"}, and ${snapshot.drives.size} drive${if (snapshot.drives.size == 1) "" else "s"}."
            }.onFailure { error ->
                _message.value = "TeslaMate connection failed: ${error.localizedMessage ?: "unknown error"}"
            }
            _isLoading.value = false
        }
    }

    fun importFetchedCharges(sessionStore: TeslaFiSessionStore, defaultVehicleId: String): Int {
        val imported = _snapshot.value.charges.mapNotNull { charge ->
            charge.toChargingSession(defaultVehicleId)
        }
        val count = sessionStore.importSessions(imported)
        _message.value = if (count == 0) {
            "No new TeslaMate charges were imported. They may already be saved or missing energy/date fields."
        } else {
            "Imported $count TeslaMate charge${if (count == 1) "" else "s"} into charging history."
        }
        return count
    }
}

private class TeslaMateApiClient(private val config: TeslaMateConnectionConfig) {
    fun fetchSnapshot(): TeslaMateSnapshot {
        val carsJson = getFirst(listOf("/api/v1/cars", "/api/cars", "/api/car"))
        val cars = parseCars(carsJson)
        val selectedCar = cars.firstOrNull { it.id == config.selectedCarId } ?: cars.firstOrNull()

        val status = selectedCar?.let {
            runCatching {
                parseStatus(getFirst(listOf("/api/v1/cars/${it.id}/status", "/api/car/${it.id}/status", "/api/car/status")))
            }.getOrNull()
        }
        val charges = selectedCar?.let {
            runCatching {
                parseCharges(getFirst(listOf("/api/v1/cars/${it.id}/charges", "/api/car/${it.id}/charges", "/api/car/charges")))
            }.getOrDefault(emptyList())
        }.orEmpty()
        val drives = selectedCar?.let {
            runCatching {
                parseDrives(getFirst(listOf("/api/v1/cars/${it.id}/drives", "/api/car/${it.id}/drives", "/api/car/drives")))
            }.getOrDefault(emptyList())
        }.orEmpty()

        return TeslaMateSnapshot(cars = cars, status = status, charges = charges, drives = drives)
    }

    private fun getFirst(paths: List<String>): JSONObject {
        var lastError: Throwable? = null
        for (path in paths) {
            runCatching { return get(path) }.onFailure { lastError = it }
        }
        throw lastError ?: IllegalStateException("No TeslaMate endpoint responded")
    }

    private fun get(path: String): JSONObject {
        val base = config.baseUrl.trim().trimEnd('/')
        val normalizedPath = if (path.startsWith("/")) path else "/$path"
        val token = config.token.trim()
        val separator = if (normalizedPath.contains("?")) "&" else "?"
        val tokenQuery = if (config.useQueryToken && token.isNotEmpty()) {
            separator + "token=" + URLEncoder.encode(token.removePrefix("?token=").removePrefix("token="), "UTF-8")
        } else {
            ""
        }
        val connection = (URL(base + normalizedPath + tokenQuery).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 10_000
            readTimeout = 15_000
            if (!config.useQueryToken && token.isNotEmpty()) {
                setRequestProperty("Authorization", "Bearer $token")
            }
        }
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        if (code !in 200..299) throw IllegalStateException("HTTP $code")
        return body.trim().let {
            if (it.startsWith("[")) JSONObject().put("data", JSONArray(it)) else JSONObject(it)
        }
    }
}

private fun parseCars(json: JSONObject): List<TeslaMateCar> {
    val array = json.arrayAt("data.cars")
        ?: json.arrayAt("data.vehicles")
        ?: json.optJSONArray("cars")
        ?: json.optJSONArray("vehicles")
        ?: json.optJSONArray("data")
        ?: JSONArray().also { json.objectAt("data.car")?.let(it::put) }

    return List(array.length()) { array.optJSONObject(it) }
        .mapNotNull { item ->
            val flat = item.flatten("car", "vehicle", "car_details")
            val id = flat.firstDouble("car_id", "vehicle_id", "id")?.toInt() ?: return@mapNotNull null
            TeslaMateCar(
                id = id,
                name = flat.firstString("name", "car_name", "display_name", "vehicle_name") ?: "Car $id",
                model = flat.firstString("model", "trim_badging"),
                vin = flat.firstString("vin")
            )
        }
}

private fun parseCharges(json: JSONObject): List<TeslaMateCharge> {
    val array = json.arrayAt("data.charges")
        ?: json.arrayAt("data.charging_processes")
        ?: json.optJSONArray("charges")
        ?: json.optJSONArray("charging_processes")
        ?: json.optJSONArray("data")
        ?: JSONArray()

    return List(array.length()) { array.optJSONObject(it) }
        .mapNotNull { item ->
            val flat = item.flatten("charge", "charging_process", "battery_details", "charger_details", "car_geodata", "geofence")
            val id = flat.firstDouble("id", "charge_id", "charging_process_id")?.toInt() ?: return@mapNotNull null
            TeslaMateCharge(
                id = id,
                startedAt = flat.firstString("start_date", "start_date_time", "start_date_time_utc", "started_at", "date"),
                endedAt = flat.firstString("end_date", "end_date_time", "end_date_time_utc", "ended_at"),
                energyKwh = flat.firstDouble("energy_added", "energy_added_kwh", "kwh", "charge_energy_added", "charge_energy_added_kwh"),
                cost = flat.firstDouble("cost", "price", "total_cost", "charge_cost"),
                location = flat.firstString("geofence", "location", "address", "name"),
                powerKw = flat.firstDouble("charge_power", "power", "max_power", "charger_power", "charger_power_kw"),
                startSoc = flat.firstDouble("start_battery_level", "battery_level_start", "start_soc")?.toInt(),
                endSoc = flat.firstDouble("end_battery_level", "battery_level_end", "end_soc", "battery_level")?.toInt()
            )
        }
        .sortedByDescending { it.startedAt.orEmpty() }
}

private fun parseDrives(json: JSONObject): List<TeslaMateDrive> {
    val array = json.arrayAt("data.drives")
        ?: json.optJSONArray("drives")
        ?: json.optJSONArray("data")
        ?: JSONArray()

    return List(array.length()) { array.optJSONObject(it) }
        .mapNotNull { item ->
            val flat = item.flatten("drive", "start_position", "end_position")
            val id = flat.firstDouble("id", "drive_id")?.toInt() ?: return@mapNotNull null
            TeslaMateDrive(
                id = id,
                startedAt = flat.firstString("start_date", "start_date_time", "start_date_time_utc", "started_at", "date"),
                endedAt = flat.firstString("end_date", "end_date_time", "end_date_time_utc", "ended_at"),
                distance = flat.firstDouble("distance", "distance_mi", "distance_km"),
                energyKwh = flat.firstDouble("energy_used", "energy_used_kwh", "kwh_used", "consumption_kwh"),
                cost = flat.firstDouble("cost", "drive_cost"),
                efficiencyWhPerMile = flat.firstDouble("efficiency", "wh_per_mile", "avg_wh_per_mile", "consumption")
            )
        }
        .sortedByDescending { it.startedAt.orEmpty() }
}

private fun parseStatus(json: JSONObject): TeslaMateStatus {
    val root = json.objectAt("data.status")
        ?: json.optJSONObject("status")
        ?: json.optJSONObject("data")
        ?: json
    val flat = root.flatten(
        "battery_details",
        "car_status",
        "car_details",
        "car_geodata",
        "car_versions",
        "driving_details",
        "climate_details",
        "charger_details"
    )
    return TeslaMateStatus(
        batteryLevel = flat.firstDouble("battery_level")?.toInt(),
        usableBatteryLevel = flat.firstDouble("usable_battery_level", "usable_battery")?.toInt(),
        chargingState = flat.firstString("charging_state", "charger_phases", "plugged_in"),
        vehicleState = flat.firstString("state", "vehicle_state"),
        ratedRange = flat.firstDouble("rated_battery_range", "battery_range", "est_battery_range"),
        idealRange = flat.firstDouble("ideal_battery_range"),
        locked = flat.firstBoolean("locked"),
        sentryMode = flat.firstBoolean("sentry_mode", "sentry_mode_available"),
        climateOn = flat.firstBoolean("is_climate_on", "climate_on"),
        softwareVersion = flat.firstString("car_version", "software_version", "version")
    )
}

private fun TeslaMateCharge.toChargingSession(defaultVehicleId: String): ChargingSession? {
    val start = startedAt?.toLocalDateTimeFlexible() ?: return null
    val energy = energyKwh?.takeIf { it > 0.0 } ?: return null
    val end = endedAt?.toLocalDateTimeFlexible() ?: start
    val station = location?.takeIf { it.isNotBlank() } ?: "TeslaMate charge"
    return ChargingSession(
        id = "teslamate-$id-${start}",
        vehicleId = defaultVehicleId,
        stationName = station,
        provider = if (station.contains("supercharg", ignoreCase = true)) "Tesla Supercharger" else "TeslaMate",
        startedAt = start,
        endedAt = if (end.isBefore(start)) start else end,
        energyAddedKWh = energy,
        cost = cost ?: 0.0,
        startSoc = startSoc ?: 0,
        endSoc = endSoc ?: 0,
        maxPowerKw = powerKw?.toInt() ?: 0,
        isSupercharger = station.contains("supercharg", ignoreCase = true)
    )
}

private fun String.toLocalDateTimeFlexible(): LocalDateTime? {
    val trimmed = trim()
    return runCatching { LocalDateTime.parse(trimmed) }.getOrNull()
        ?: runCatching { OffsetDateTime.parse(trimmed).toLocalDateTime() }.getOrNull()
        ?: listOf(
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss Z",
            "M/d/yyyy h:mm:ss a",
            "MM/dd/yyyy HH:mm:ss"
        ).firstNotNullOfOrNull { pattern ->
            runCatching { LocalDateTime.parse(trimmed, DateTimeFormatter.ofPattern(pattern, Locale.US)) }.getOrNull()
        }
}

private fun JSONObject.flatten(vararg nestedKeys: String): JSONObject {
    val out = JSONObject(toString())
    nestedKeys.forEach { key ->
        optJSONObject(key)?.let { nested ->
            nested.keys().forEach { nestedKey ->
                if (!out.has(nestedKey)) out.put(nestedKey, nested.opt(nestedKey))
            }
        }
    }
    return out
}

private fun JSONObject.firstString(vararg keys: String): String? =
    keys.firstNotNullOfOrNull { key -> optString(key).trim().takeIf { it.isNotEmpty() && it != "null" } }

private fun JSONObject.firstDouble(vararg keys: String): Double? =
    keys.firstNotNullOfOrNull { key -> if (has(key) && !isNull(key)) optDouble(key).takeIf { !it.isNaN() } else null }

private fun JSONObject.firstBoolean(vararg keys: String): Boolean? =
    keys.firstNotNullOfOrNull { key -> if (has(key) && !isNull(key)) optBoolean(key) else null }

private fun JSONObject.objectAt(path: String): JSONObject? {
    var current: JSONObject = this
    path.split('.').forEachIndexed { index, part ->
        val next = current.optJSONObject(part) ?: return null
        if (index == path.split('.').lastIndex) return next
        current = next
    }
    return current
}

private fun JSONObject.arrayAt(path: String): JSONArray? {
    var current: JSONObject = this
    val parts = path.split('.')
    parts.dropLast(1).forEach { part ->
        current = current.optJSONObject(part) ?: return null
    }
    return current.optJSONArray(parts.last())
}
