package com.myevcompanion.app.data

import android.content.Context
import android.util.AtomicFile
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

private val storeScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

private class JsonBackedFile(
    context: Context,
    fileName: String
) {
    private val file = File(context.filesDir, fileName)
    private val atomicFile = AtomicFile(file)

    fun readObject(): JSONObject? {
        if (!file.exists()) return null
        return runCatching {
            atomicFile.openRead().bufferedReader(Charsets.UTF_8).use { reader ->
                JSONObject(reader.readText())
            }
        }.getOrNull()
    }

    fun writeObject(json: JSONObject) {
        storeScope.launch {
            var stream: java.io.FileOutputStream? = null
            try {
                stream = atomicFile.startWrite()
                stream.write(json.toString().toByteArray(Charsets.UTF_8))
                atomicFile.finishWrite(stream)
            } catch (error: Throwable) {
                stream?.let { atomicFile.failWrite(it) }
            }
        }
    }
}

private fun Color.toHex(): String = String.format(Locale.US, "#%08X", toArgb())

private fun String.toColorOr(default: Color): Color {
    return runCatching {
        val normalized = removePrefix("#")
        val argb = normalized.toLong(16)
        Color(argb.toInt())
    }.getOrDefault(default)
}

private fun VehicleProfile.toJson(): JSONObject = JSONObject()
    .put("id", id)
    .put("name", name)
    .put("make", make)
    .put("model", model)
    .put("year", year)
    .put("vin", vin)
    .put("plateOrMarker", plateOrMarker)
    .put("isEv", isEv)
    .put("batteryCapacityKWh", batteryCapacityKWh)
    .put("efficiencyWhPerMile", efficiencyWhPerMile)
    .put("estimatedRangeMiles", estimatedRangeMiles)
    .put("accent", accent.toHex())
    .put("notes", notes)

private fun JSONObject.toVehicleProfile(): VehicleProfile = VehicleProfile(
    id = optString("id"),
    name = optString("name"),
    make = optString("make"),
    model = optString("model"),
    year = optInt("year"),
    vin = optString("vin"),
    plateOrMarker = optString("plateOrMarker"),
    isEv = optBoolean("isEv", true),
    batteryCapacityKWh = optDouble("batteryCapacityKWh"),
    efficiencyWhPerMile = optDouble("efficiencyWhPerMile"),
    estimatedRangeMiles = optDouble("estimatedRangeMiles"),
    accent = optString("accent").toColorOr(Color(0xFF16C79A)),
    notes = optString("notes")
)

private fun ExpenseEntry.toJson(): JSONObject = JSONObject()
    .put("id", id)
    .put("title", title)
    .put("category", category.name)
    .put("amount", amount)
    .put("energyKWh", energyKWh)
    .put("date", date.toString())
    .put("location", location)
    .put("vehicleId", vehicleId)
    .put("notes", notes)

private fun JSONObject.toExpenseEntry(): ExpenseEntry = ExpenseEntry(
    id = optString("id"),
    title = optString("title"),
    category = EntryCategory.valueOf(optString("category")),
    amount = optDouble("amount"),
    energyKWh = if (isNull("energyKWh")) null else optDouble("energyKWh"),
    date = LocalDate.parse(optString("date")),
    location = optString("location"),
    vehicleId = optString("vehicleId"),
    notes = optString("notes")
)

private fun ChargingSession.toJson(): JSONObject = JSONObject()
    .put("id", id)
    .put("vehicleId", vehicleId)
    .put("stationName", stationName)
    .put("provider", provider)
    .put("startedAt", startedAt.toString())
    .put("endedAt", endedAt.toString())
    .put("energyAddedKWh", energyAddedKWh)
    .put("cost", cost)
    .put("startSoc", startSoc)
    .put("endSoc", endSoc)
    .put("maxPowerKw", maxPowerKw)
    .put("isSupercharger", isSupercharger)

private fun JSONObject.toChargingSession(): ChargingSession = ChargingSession(
    id = optString("id"),
    vehicleId = optString("vehicleId"),
    stationName = optString("stationName"),
    provider = optString("provider"),
    startedAt = LocalDateTime.parse(optString("startedAt")),
    endedAt = LocalDateTime.parse(optString("endedAt")),
    energyAddedKWh = optDouble("energyAddedKWh"),
    cost = optDouble("cost"),
    startSoc = optInt("startSoc"),
    endSoc = optInt("endSoc"),
    maxPowerKw = optInt("maxPowerKw"),
    isSupercharger = optBoolean("isSupercharger")
)

private fun JSONArray.toVehicleList(): List<VehicleProfile> =
    List(length()) { index -> getJSONObject(index).toVehicleProfile() }

private fun JSONArray.toEntryList(): List<ExpenseEntry> =
    List(length()) { index -> getJSONObject(index).toExpenseEntry() }

private fun JSONArray.toSessionList(): List<ChargingSession> =
    List(length()) { index -> getJSONObject(index).toChargingSession() }

private fun vehicleJsonArray(vehicles: List<VehicleProfile>): JSONArray = JSONArray().apply {
    vehicles.forEach { put(it.toJson()) }
}

private fun entryJsonArray(entries: List<ExpenseEntry>): JSONArray = JSONArray().apply {
    entries.forEach { put(it.toJson()) }
}

private fun sessionJsonArray(sessions: List<ChargingSession>): JSONArray = JSONArray().apply {
    sessions.forEach { put(it.toJson()) }
}

private fun csvEscape(value: String): String {
    val escaped = value.replace("\"", "\"\"")
    return if (escaped.any { it == ',' || it == '\n' || it == '"' }) "\"$escaped\"" else escaped
}

private fun parseCsvLine(line: String): List<String> {
    val cells = mutableListOf<String>()
    val current = StringBuilder()
    var inQuotes = false
    var index = 0
    while (index < line.length) {
        val char = line[index]
        when {
            char == '"' && inQuotes && index + 1 < line.length && line[index + 1] == '"' -> {
                current.append('"')
                index++
            }

            char == '"' -> inQuotes = !inQuotes
            char == ',' && !inQuotes -> {
                cells += current.toString()
                current.clear()
            }

            else -> current.append(char)
        }
        index++
    }
    cells += current.toString()
    return cells
}

private fun parseCsv(csv: String): List<Map<String, String>> {
    val lines = csv.lineSequence().map { it.trimEnd() }.filter { it.isNotBlank() }.toList()
    if (lines.isEmpty()) return emptyList()
    val headers = parseCsvLine(lines.first()).map { it.trim() }
    return lines.drop(1).map { line ->
        val values = parseCsvLine(line)
        headers.mapIndexed { index, header -> header to values.getOrElse(index) { "" } }.toMap()
    }
}

private fun Map<String, String>.csvValue(key: String): String =
    entries.firstOrNull { it.key.equals(key, ignoreCase = true) }?.value?.trim().orEmpty()

private fun String.normalizedLookupKey(): String =
    lowercase(Locale.US)
        .replace("[^a-z0-9]".toRegex(), "")

private val legacyVehicleNames = setOf(
    "Midnight Model Y".normalizedLookupKey(),
    "Hudson R1T".normalizedLookupKey()
)

private val legacyEntryTitles = setOf(
    "Home charging top-up".normalizedLookupKey(),
    "Supercharger in Newark".normalizedLookupKey(),
    "Tire rotation".normalizedLookupKey(),
    "Insurance payment".normalizedLookupKey(),
    "Bed rack accessories".normalizedLookupKey()
)

private val legacySessionStations = setOf(
    "Brooklyn Garage".normalizedLookupKey(),
    "Newark V3".normalizedLookupKey(),
    "Kingston Rivian Waypoint".normalizedLookupKey()
)

private fun List<VehicleProfile>.withoutLegacyVehicleSeed(): List<VehicleProfile> {
    if (isEmpty()) return this
    val currentKeys = map { it.name.normalizedLookupKey() }.toSet()
    return if (currentKeys == legacyVehicleNames) emptyList() else this
}

private fun List<ExpenseEntry>.withoutLegacyEntrySeed(): List<ExpenseEntry> {
    if (isEmpty()) return this
    val currentKeys = map { it.title.normalizedLookupKey() }.toSet()
    return if (currentKeys == legacyEntryTitles) emptyList() else this
}

private fun List<ChargingSession>.withoutLegacySessionSeed(): List<ChargingSession> {
    if (isEmpty()) return this
    val currentKeys = map { it.stationName.normalizedLookupKey() }.toSet()
    return if (currentKeys == legacySessionStations) emptyList() else this
}

private fun parseTeslaCsvNumber(raw: String): Double? {
    if (raw.isBlank()) return null
    var value = raw.trim()
        .replace("$", "")
        .replace("€", "")
        .replace("£", "")
        .replace("kwh", "", ignoreCase = true)
        .replace("kw h", "", ignoreCase = true)

    val hasComma = value.contains(",")
    val hasDot = value.contains(".")
    if (hasComma && hasDot) {
        val lastComma = value.lastIndexOf(',')
        val lastDot = value.lastIndexOf('.')
        value = if (lastComma > lastDot) {
            value.replace(".", "").replace(",", ".")
        } else {
            value.replace(",", "")
        }
    } else if (hasComma) {
        value = value.replace(",", ".")
    }

    val cleaned = value.filter { it in "+-0123456789.eE" }
    return cleaned.toDoubleOrNull()
}

private fun parseTeslaCsvDate(raw: String): LocalDateTime? {
    val text = raw.trim()
    if (text.isBlank()) return null

    val formatters = listOf(
        DateTimeFormatter.ISO_DATE_TIME,
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"),
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"),
        DateTimeFormatter.ofPattern("M/d/yyyy H:mm"),
        DateTimeFormatter.ofPattern("M/d/yy H:mm"),
        DateTimeFormatter.ofPattern("MM/dd/yyyy HH:mm"),
        DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")
    )

    return formatters.firstNotNullOfOrNull { formatter ->
        runCatching { LocalDateTime.parse(text, formatter) }.getOrNull()
    }
}

private fun teslaImportEntryKey(
    date: LocalDate,
    location: String,
    amount: Double,
    energyKWh: Double?
): String {
    val roundedAmount = "%.2f".format(Locale.US, amount)
    val roundedEnergy = energyKWh?.let { "%.3f".format(Locale.US, it) } ?: "-"
    return listOf(date, location.trim().normalizedLookupKey(), roundedAmount, roundedEnergy).joinToString("|")
}

class ProfileStore(context: Context) {
    private val file = JsonBackedFile(context, "vehicles.json")
    private val initialPayload = file.readObject()

    private val _vehicles = MutableStateFlow(
        initialPayload?.optJSONArray("vehicles")?.toVehicleList()?.withoutLegacyVehicleSeed() ?: emptyList()
    )
    val vehicles: StateFlow<List<VehicleProfile>> = _vehicles

    private val _selectedVehicleId = MutableStateFlow(
        initialPayload?.optString("selectedVehicleId")?.takeIf { it.isNotBlank() }
            ?.takeIf { selected -> _vehicles.value.any { it.id == selected } }
            ?: _vehicles.value.firstOrNull()?.id.orEmpty()
    )
    val selectedVehicleId: StateFlow<String> = _selectedVehicleId

    fun selectVehicle(id: String) {
        if (_vehicles.value.none { it.id == id }) return
        _selectedVehicleId.value = id
        persist()
    }

    fun activeVehicle(): VehicleProfile? {
        return _vehicles.value.firstOrNull { it.id == _selectedVehicleId.value }
    }

    fun saveVehicle(vehicle: VehicleProfile) {
        _vehicles.update { existing ->
            val mutable = existing.toMutableList()
            val index = mutable.indexOfFirst { it.id == vehicle.id }
            if (index >= 0) mutable[index] = vehicle else mutable.add(0, vehicle)
            mutable.sortedBy { it.name.lowercase(Locale.US) }
        }
        _selectedVehicleId.value = vehicle.id
        persist()
    }

    fun resolveVehicleIdForTeslaImport(
        vehicleName: String?,
        vin: String?,
        fallbackVehicleId: String
    ): Pair<String, Boolean> {
        val normalizedVin = vin?.trim()?.takeIf { it.isNotBlank() }
        val normalizedName = vehicleName?.trim()?.takeIf { it.isNotBlank() }

        _vehicles.value.firstOrNull { candidate ->
            normalizedVin != null && candidate.vin.equals(normalizedVin, ignoreCase = true)
        }?.let { return it.id to false }

        _vehicles.value.firstOrNull { candidate ->
            normalizedName != null && candidate.name.equals(normalizedName, ignoreCase = true)
        }?.let { return it.id to false }

        if (fallbackVehicleId.isNotBlank() && _vehicles.value.any { it.id == fallbackVehicleId }) {
            return fallbackVehicleId to false
        }

        if (normalizedName == null && normalizedVin == null) {
            return "" to false
        }

        val importedVehicle = VehicleProfile(
            name = normalizedName ?: "Imported Tesla",
            make = "Tesla",
            model = normalizedName ?: "Imported Vehicle",
            year = LocalDate.now().year,
            vin = normalizedVin.orEmpty(),
            plateOrMarker = "",
            isEv = true,
            batteryCapacityKWh = 0.0,
            efficiencyWhPerMile = 0.0,
            estimatedRangeMiles = 0.0,
            accent = Color(0xFFE82127),
            notes = "Created from the official Tesla Supercharging CSV. Update this garage profile with your real vehicle specs."
        )
        saveVehicle(importedVehicle)
        return importedVehicle.id to true
    }

    fun deleteSelectedVehicle() {
        val targetId = _selectedVehicleId.value
        if (targetId.isBlank()) return
        _vehicles.update { list -> list.filterNot { it.id == targetId } }
        _selectedVehicleId.value = _vehicles.value.firstOrNull()?.id.orEmpty()
        persist()
    }

    private fun persist() {
        file.writeObject(
            JSONObject()
                .put("selectedVehicleId", _selectedVehicleId.value)
                .put("vehicles", vehicleJsonArray(_vehicles.value))
        )
    }
}

class EntriesStore(context: Context) {
    private val file = JsonBackedFile(context, "entries.json")
    private val initialEntries = file.readObject()?.optJSONArray("entries")?.toEntryList()?.withoutLegacyEntrySeed() ?: emptyList()
    private val _entries = MutableStateFlow(initialEntries.sortedByDescending { it.date })
    val entries: StateFlow<List<ExpenseEntry>> = _entries

    fun saveEntry(entry: ExpenseEntry) {
        _entries.update { existing ->
            val mutable = existing.toMutableList()
            val index = mutable.indexOfFirst { it.id == entry.id }
            if (index >= 0) mutable[index] = entry else mutable.add(entry)
            mutable.sortedByDescending { it.date }
        }
        persist()
    }

    fun deleteEntry(id: String) {
        _entries.update { it.filterNot { entry -> entry.id == id } }
        persist()
    }

    fun exportCsv(): String {
        val header = listOf("id", "title", "category", "amount", "energyKWh", "date", "location", "vehicleId", "notes")
        val rows = _entries.value.joinToString("\n") { entry ->
            listOf(
                entry.id,
                entry.title,
                entry.category.name,
                entry.amount.toString(),
                entry.energyKWh?.toString().orEmpty(),
                entry.date.toString(),
                entry.location,
                entry.vehicleId,
                entry.notes
            ).joinToString(",") { csvEscape(it) }
        }
        return header.joinToString(",") + "\n" + rows
    }

    fun importCsv(csv: String, defaultVehicleId: String): Int {
        val imported = parseCsv(csv).mapNotNull { row ->
            val title = row.csvValue("title")
            val amount = row.csvValue("amount").toDoubleOrNull()
            val date = row.csvValue("date")
                .takeIf { it.isNotBlank() }
                ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            if (title.isBlank() || amount == null || date == null) return@mapNotNull null
            ExpenseEntry(
                id = row.csvValue("id").ifBlank { java.util.UUID.randomUUID().toString() },
                title = title,
                category = runCatching { EntryCategory.valueOf(row.csvValue("category")) }
                    .getOrDefault(EntryCategory.Charging),
                amount = amount,
                energyKWh = row.csvValue("energyKWh").toDoubleOrNull(),
                date = date,
                location = row.csvValue("location").ifBlank { "Imported CSV" },
                vehicleId = row.csvValue("vehicleId").ifBlank { defaultVehicleId },
                notes = row.csvValue("notes")
            )
        }
        if (imported.isEmpty()) return 0
        _entries.update { existing ->
            (existing.associateBy { it.id } + imported.associateBy { it.id }).values
                .sortedByDescending { it.date }
        }
        persist()
        return imported.size
    }

    private fun persist() {
        file.writeObject(JSONObject().put("entries", entryJsonArray(_entries.value)))
    }
}

class TeslaFiSessionStore(context: Context) {
    private val file = JsonBackedFile(context, "sessions.json")
    private val initialSessions = file.readObject()?.optJSONArray("sessions")?.toSessionList()?.withoutLegacySessionSeed() ?: emptyList()
    private val _sessions = MutableStateFlow(initialSessions.sortedByDescending { it.startedAt })
    val sessions: StateFlow<List<ChargingSession>> = _sessions

    fun saveSession(session: ChargingSession) {
        _sessions.update { existing ->
            val mutable = existing.toMutableList()
            val index = mutable.indexOfFirst { it.id == session.id }
            if (index >= 0) mutable[index] = session else mutable.add(session)
            mutable.sortedByDescending { it.startedAt }
        }
        persist()
    }

    fun exportCsv(): String {
        val header = listOf(
            "id",
            "vehicleId",
            "stationName",
            "provider",
            "startedAt",
            "endedAt",
            "energyAddedKWh",
            "cost",
            "startSoc",
            "endSoc",
            "maxPowerKw",
            "isSupercharger"
        )
        val rows = _sessions.value.joinToString("\n") { session ->
            listOf(
                session.id,
                session.vehicleId,
                session.stationName,
                session.provider,
                session.startedAt.toString(),
                session.endedAt.toString(),
                session.energyAddedKWh.toString(),
                session.cost.toString(),
                session.startSoc.toString(),
                session.endSoc.toString(),
                session.maxPowerKw.toString(),
                session.isSupercharger.toString()
            ).joinToString(",") { csvEscape(it) }
        }
        return header.joinToString(",") + "\n" + rows
    }

    fun importCsv(csv: String, defaultVehicleId: String): Int {
        val imported = parseCsv(csv).mapNotNull { row ->
            val station = row.csvValue("stationName")
            val provider = row.csvValue("provider")
            val started = row.csvValue("startedAt")
                .takeIf { it.isNotBlank() }
                ?.let { runCatching { LocalDateTime.parse(it) }.getOrNull() }
            val ended = row.csvValue("endedAt")
                .takeIf { it.isNotBlank() }
                ?.let { runCatching { LocalDateTime.parse(it) }.getOrNull() }
            val energy = row.csvValue("energyAddedKWh").toDoubleOrNull()
            val cost = row.csvValue("cost").toDoubleOrNull()
            if (station.isBlank() || provider.isBlank() || started == null || ended == null || energy == null || cost == null) {
                return@mapNotNull null
            }
            ChargingSession(
                id = row.csvValue("id").ifBlank { java.util.UUID.randomUUID().toString() },
                vehicleId = row.csvValue("vehicleId").ifBlank { defaultVehicleId },
                stationName = station,
                provider = provider,
                startedAt = started,
                endedAt = ended,
                energyAddedKWh = energy,
                cost = cost,
                startSoc = row.csvValue("startSoc").toIntOrNull() ?: 20,
                endSoc = row.csvValue("endSoc").toIntOrNull() ?: 80,
                maxPowerKw = row.csvValue("maxPowerKw").toIntOrNull() ?: 150,
                isSupercharger = row.csvValue("isSupercharger").equals("true", ignoreCase = true)
            )
        }
        if (imported.isEmpty()) return 0
        _sessions.update { existing ->
            (existing.associateBy { it.id } + imported.associateBy { it.id }).values
                .sortedByDescending { it.startedAt }
        }
        persist()
        return imported.size
    }

    fun importSessions(imported: List<ChargingSession>): Int {
        if (imported.isEmpty()) return 0
        val existingKeys = _sessions.value.map { it.sessionImportKey() }.toSet()
        val newSessions = imported.distinctBy { it.sessionImportKey() }
            .filterNot { it.sessionImportKey() in existingKeys }
        if (newSessions.isEmpty()) return 0
        _sessions.update { existing ->
            (existing + newSessions).sortedByDescending { it.startedAt }
        }
        persist()
        return newSessions.size
    }

    private fun persist() {
        file.writeObject(JSONObject().put("sessions", sessionJsonArray(_sessions.value)))
    }
}

private fun ChargingSession.sessionImportKey(): String =
    listOf(
        vehicleId,
        stationName.normalizedLookupKey(),
        startedAt.toString(),
        endedAt.toString(),
        "%.3f".format(Locale.US, energyAddedKWh)
    ).joinToString("|")

class BudgetStore {
    private val _budget = MutableStateFlow(
        MonthlyBudget(
            monthlyLimit = 520.0,
            targetKwh = 280.0,
            targetSessions = 10
        )
    )
    val budget: StateFlow<MonthlyBudget> = _budget
}

class AppAppearance(context: Context) {
    private val prefs = context.getSharedPreferences("appearance", Context.MODE_PRIVATE)
    private val _accentHex = MutableStateFlow("#16C79A")
    val accentHex: StateFlow<String> = _accentHex

    private val _themeMode = MutableStateFlow(
        runCatching { ThemeMode.valueOf(prefs.getString("themeMode", ThemeMode.SYSTEM.name) ?: ThemeMode.SYSTEM.name) }
            .getOrDefault(ThemeMode.SYSTEM)
    )
    val themeMode: StateFlow<ThemeMode> = _themeMode

    fun setThemeMode(mode: ThemeMode) {
        _themeMode.value = mode
        prefs.edit().putString("themeMode", mode.name).apply()
    }
}

class ToolUsageStore {
    private val _usage = MutableStateFlow(
        mapOf(
            "Trip Planner" to 14,
            "Gas to kWh" to 11,
            "Battery Health" to 6
        )
    )
    val usage: StateFlow<Map<String, Int>> = _usage

    fun recordOpen(toolTitle: String) {
        _usage.update { current ->
            current + (toolTitle to ((current[toolTitle] ?: 0) + 1))
        }
    }
}

class DiscountFavoritesStore(context: Context) {
    private val prefs = context.getSharedPreferences("discount_favorites", Context.MODE_PRIVATE)
    private val _favorites = MutableStateFlow(prefs.getStringSet("urls", emptySet()).orEmpty())
    val favorites: StateFlow<Set<String>> = _favorites

    fun toggleFavorite(url: String) {
        val updated = _favorites.value.toMutableSet().apply {
            if (!add(url)) remove(url)
        }.toSet()
        _favorites.value = updated
        prefs.edit().putStringSet("urls", updated).apply()
    }

    fun isFavorite(url: String): Boolean = _favorites.value.contains(url)
}

class AppUISettings(context: Context) {
    private val prefs = context.getSharedPreferences("ui_settings", Context.MODE_PRIVATE)
    private val _hapticsEnabled = MutableStateFlow(prefs.getBoolean("hapticsEnabled", true))
    val hapticsEnabled: StateFlow<Boolean> = _hapticsEnabled

    private val _showAds = MutableStateFlow(prefs.getBoolean("showAds", true))
    val showAds: StateFlow<Boolean> = _showAds

    fun setHapticsEnabled(enabled: Boolean) {
        _hapticsEnabled.value = enabled
        prefs.edit().putBoolean("hapticsEnabled", enabled).apply()
    }

    fun setShowAds(enabled: Boolean) {
        _showAds.value = enabled
        prefs.edit().putBoolean("showAds", enabled).apply()
    }
}

class SuperchargePricingInfoStore {
    private val _stations = MutableStateFlow(SampleData.pricing)
    val stations: StateFlow<List<PricingSpotlight>> = _stations
}

class TeslaOfficialSuperchargerPricingStore {
    private val _prices = MutableStateFlow(SampleData.pricing.filter { it.provider.contains("Tesla") })
    val prices: StateFlow<List<PricingSpotlight>> = _prices
}

class KWhGasCompanionAppModel(
    val teslaFiStore: TeslaFiSessionStore,
    val profileStore: ProfileStore,
    val entriesStore: EntriesStore
) {
    private data class ChargingObservation(
        val index: Int,
        val provider: String,
        val energyKwh: Double,
        val cost: Double,
        val weekdayValue: Int
    ) {
        val costPerKwh: Double
            get() = if (energyKwh > 0.0) cost / energyKwh else 0.0
    }

    data class TeslaOfficialCsvImportResult(
        val importedEntries: Int,
        val skippedRows: Int,
        val backfilledKwhRows: Int,
        val autoCreatedVehicles: Int
    )

    fun dashboardSnapshot(): DashboardSnapshot {
        val sessions = teslaFiStore.sessions.value
        val entries = entriesStore.entries.value
        val activeVehicle = profileStore.activeVehicle()

        val energyEntries = entries.filter { it.category == EntryCategory.Charging && it.energyKWh != null }
        val totalEnergy = energyEntries.sumOf { it.energyKWh ?: 0.0 }
        val totalSpend = entries.sumOf { it.amount }
        val avgCostPerKwh = if (totalEnergy > 0.0) totalSpend / totalEnergy else 0.0

        val provider = sessions
            .groupBy { it.provider }
            .maxByOrNull { (_, grouped) -> grouped.size }
            ?.key
            ?: entries
                .filter { it.category == EntryCategory.Charging }
                .maxByOrNull { it.amount }
                ?.let { if (it.location.contains("tesla", ignoreCase = true) || it.location.contains("supercharg", ignoreCase = true)) "Tesla Supercharger" else "Charging" }
            ?: "No charging history"

        return DashboardSnapshot(
            totalSpend = totalSpend,
            energyThisMonth = totalEnergy,
            avgCostPerKwh = avgCostPerKwh,
            sessionCount = sessions.size,
            topProvider = provider,
            activeVehicle = activeVehicle,
            recentSessions = sessions.sortedByDescending { it.startedAt }.take(3),
            recentEntries = entries.sortedByDescending { it.date }.take(4),
            insights = buildDashboardInsights(activeVehicle, sessions, entries),
            chargingMlInsight = chargingMlInsight()
        )
    }

    fun chargingMlInsight(): ChargingMlInsight {
        val sessionObservations = teslaFiStore.sessions.value
            .sortedBy { it.startedAt }
            .filter { it.energyAddedKWh > 0.0 && it.cost >= 0.0 }
            .mapIndexed { index, session ->
                ChargingObservation(
                    index = index,
                    provider = session.provider.ifBlank { session.stationName.ifBlank { "Charging" } },
                    energyKwh = session.energyAddedKWh,
                    cost = session.cost,
                    weekdayValue = session.startedAt.dayOfWeek.value
                )
            }

        val entryObservations = entriesStore.entries.value
            .filter { it.category == EntryCategory.Charging && (it.energyKWh ?: 0.0) > 0.0 }
            .sortedBy { it.date }
            .mapIndexed { index, entry ->
                ChargingObservation(
                    index = index,
                    provider = entry.location.ifBlank { entry.title.ifBlank { "Charging" } },
                    energyKwh = entry.energyKWh ?: 0.0,
                    cost = entry.amount,
                    weekdayValue = entry.date.dayOfWeek.value
                )
            }

        val observations = sessionObservations.ifEmpty { entryObservations }

        if (observations.size < 2) {
            val fallback = observations.firstOrNull()
            return ChargingMlInsight(
                summary = "Add at least two charging records with both cost and kWh to activate the first on-device ML layer for charge forecasting and anomaly detection.",
                confidenceLabel = if (fallback == null) "No data" else "Very low",
                sampleCount = observations.size,
                trendLabel = "Not enough history",
                nextSessionCost = fallback?.cost,
                nextSessionEnergyKwh = fallback?.energyKwh,
                typicalCostPerKwh = fallback?.costPerKwh,
                priciestProvider = fallback?.provider ?: "Unknown",
                anomalyLabel = "No anomaly baseline yet",
                strongestSignals = listOf(
                    "History depth" to "${observations.size} usable rows",
                    "Model family" to "Neural net standby",
                    "Provider mix" to (fallback?.provider ?: "Unknown"),
                    "Data readiness" to "Need more samples"
                ),
                providerForecasts = listOf(
                    (fallback?.provider ?: "Charging") to "Need more provider history"
                ),
                anomalyCandidates = listOf(
                    "Outlier engine" to "Waiting for a baseline"
                )
            )
        }

        val neuralForecast = ChargingNeuralForecaster.forecast(
            observations.map { observation ->
                ChargingForecastInput(
                    sessionIndex = observation.index,
                    provider = observation.provider,
                    weekdayValue = observation.weekdayValue,
                    energyKwh = observation.energyKwh,
                    cost = observation.cost,
                    isHome = observation.provider.contains("home", ignoreCase = true)
                )
            }
        )
        val energyForecast = neuralForecast?.predictedEnergyKwh
        val costForecast = neuralForecast?.predictedCost
        val averageRate = observations.map { it.costPerKwh }.average().takeIf { it > 0.0 }
        val oldestHalf = observations.take((observations.size / 2).coerceAtLeast(1)).map { it.costPerKwh }.average()
        val newestHalf = observations.takeLast((observations.size / 2).coerceAtLeast(1)).map { it.costPerKwh }.average()
        val changeRatio = if (oldestHalf > 0.0) (newestHalf - oldestHalf) / oldestHalf else 0.0
        val homeShare = observations.count { it.provider.contains("home", ignoreCase = true) }
            .toDouble() / observations.size.toDouble()
        val weekendShare = observations.count { observation -> observation.weekdayValue in listOf(6, 7) }
            .toDouble() / observations.size.toDouble()
        val trendLabel = when {
            changeRatio > 0.08 -> "Rates rising ${percentLabel(changeRatio)}"
            changeRatio < -0.08 -> "Rates easing ${percentLabel(abs(changeRatio))}"
            else -> "Rates stable"
        }
        val priciestProvider = observations
            .groupBy { it.provider }
            .maxByOrNull { (_, rows) -> rows.map { it.costPerKwh }.average() }
            ?.key
            ?: "Unknown"
        val anomalyObservation = observations
            .map { observation ->
                val delta = if (averageRate != null) observation.costPerKwh - averageRate else 0.0
                observation to delta
            }
            .maxByOrNull { (_, delta) -> abs(delta) }
        val anomalyLabel = anomalyObservation?.let { (observation, delta) ->
            if (averageRate == null || averageRate <= 0.0) {
                "No anomaly baseline yet"
            } else {
                val deviation = abs(delta / averageRate)
                when {
                    deviation >= 0.2 && delta > 0.0 -> "${observation.provider} ran ${percentLabel(deviation)} above baseline"
                    deviation >= 0.2 && delta < 0.0 -> "${observation.provider} ran ${percentLabel(deviation)} below baseline"
                    else -> "No strong outlier in recent history"
                }
            }
        } ?: "No strong outlier in recent history"
        val confidenceLabel = when {
            neuralForecast != null && observations.size >= 12 && neuralForecast.costRmse <= 4.0 -> "Medium"
            neuralForecast != null && observations.size >= 6 && neuralForecast.costRmse <= 8.0 -> "Low-medium"
            else -> "Low"
        }
        val strongestSignals = listOf(
            "History depth" to "${observations.size} sessions",
            "Model family" to (neuralForecast?.modelLabel ?: "Neural net"),
            "RL stage" to (neuralForecast?.reinforcementStageLabel ?: "Waiting for baseline"),
            "Rate drift" to trendLabel,
            "Home share" to percentLabel(homeShare),
            "Weekend share" to percentLabel(weekendShare),
            "Fit quality" to (neuralForecast?.summaryLabel ?: "Early fit")
        )
        val providerForecasts = observations
            .groupBy { it.provider }
            .entries
            .sortedByDescending { (_, rows) -> rows.size }
            .take(3)
            .map { (provider, rows) ->
                val avgRate = rows.map { it.costPerKwh }.average()
                val avgEnergy = rows.map { it.energyKwh }.average()
                provider to "${avgRate.rateCurrency()}/kWh • ${avgEnergy.oneDecimalValue()} kWh typical"
            }
        val anomalyCandidates = observations
            .filter { averageRate != null && averageRate > 0.0 }
            .sortedByDescending { observation -> abs(observation.costPerKwh - averageRate!!) }
            .take(3)
            .map { observation ->
                val deviation = abs((observation.costPerKwh - averageRate!!) / averageRate)
                observation.provider to "${observation.costPerKwh.rateCurrency()}/kWh • ${percentLabel(deviation)} from baseline"
            }
        val summary = buildString {
            append("This ML layer uses a tiny on-device neural network over your saved charging history, then runs a reinforcement-learning fine-tune that rewards lower forecast error and smaller policy adjustments. ")
            append("It forecasts the next session at ")
            append(
                listOfNotNull(
                    costForecast?.let { "$${"%.2f".format(Locale.US, it)}" },
                    energyForecast?.let { "${"%.1f".format(Locale.US, it)} kWh" }
                ).joinToString(" and ").ifBlank { "an unavailable estimate" }
            )
            append(", sees the pricing trend as ")
            append(trendLabel.lowercase(Locale.US))
            append(", and currently flags ")
            append(anomalyLabel.lowercase(Locale.US))
            neuralForecast?.let {
                append(". Current training fit is ")
                append(it.summaryLabel.lowercase(Locale.US))
                append(" with an RMSE of ")
                append("$${"%.2f".format(Locale.US, it.costRmse)} on cost and ")
                append("${"%.3f".format(Locale.US, it.rateRmse)}/kWh on rate")
                append(". The RL stage is ")
                append(it.reinforcementStageLabel.lowercase(Locale.US))
            }
            append(".")
        }

        return ChargingMlInsight(
            summary = summary,
            confidenceLabel = confidenceLabel,
            sampleCount = observations.size,
            trendLabel = trendLabel,
            nextSessionCost = costForecast,
            nextSessionEnergyKwh = energyForecast,
            typicalCostPerKwh = averageRate,
            priciestProvider = priciestProvider,
            anomalyLabel = anomalyLabel,
            strongestSignals = strongestSignals,
            providerForecasts = providerForecasts,
            anomalyCandidates = anomalyCandidates
        )
    }

    fun importOfficialTeslaSuperchargingCsv(csv: String): TeslaOfficialCsvImportResult {
        val rows = parseCsv(csv)
        if (rows.isEmpty()) {
            return TeslaOfficialCsvImportResult(0, 0, 0, 0)
        }

        val existingKeys = entriesStore.entries.value
            .filter { it.category == EntryCategory.Charging }
            .map { teslaImportEntryKey(it.date, it.location, it.amount, it.energyKWh) }
            .toMutableSet()

        var importedEntries = 0
        var skippedRows = 0
        var backfilledRows = 0
        var autoCreatedVehicles = 0
        val fallbackVehicleId = profileStore.selectedVehicleId.value

        rows.forEach { row ->
            val startedAt = parseTeslaCsvDate(row.csvValue("ChargeStartDateTime"))
            val location = row.csvValue("SiteLocationName").ifBlank { "Tesla Supercharger" }
            val invoiceNumber = row.csvValue("InvoiceNumber")
            val vehicleName = row.csvValue("Name")
            val vin = row.csvValue("Vin")
            val description = row.csvValue("Description")

            val pricePerKwh = parseTeslaCsvNumber(row.csvValue("UnitCostBase"))
            val explicitEnergy = parseTeslaCsvNumber(row.csvValue("QuantityBase"))
            val vatAmount = parseTeslaCsvNumber(row.csvValue("VAT"))
            val totalExcVat = parseTeslaCsvNumber(row.csvValue("Total Exc. VAT"))
            val totalIncVat = parseTeslaCsvNumber(row.csvValue("Total Inc. VAT"))
            val taxInclusiveFallback = if (totalExcVat != null && vatAmount != null) totalExcVat + vatAmount else null

            val grossAmount = totalIncVat
                ?: taxInclusiveFallback
                ?: if (explicitEnergy != null && pricePerKwh != null) explicitEnergy * pricePerKwh else null

            val energyKwh = explicitEnergy ?: if (grossAmount != null && pricePerKwh != null && pricePerKwh > 0.0) {
                backfilledRows += 1
                grossAmount / pricePerKwh
            } else {
                null
            }

            if (startedAt == null || grossAmount == null) {
                skippedRows += 1
                return@forEach
            }

            val (vehicleId, createdVehicle) = profileStore.resolveVehicleIdForTeslaImport(
                vehicleName = vehicleName,
                vin = vin,
                fallbackVehicleId = fallbackVehicleId
            )
            if (createdVehicle) autoCreatedVehicles += 1

            val dedupeKey = teslaImportEntryKey(
                date = startedAt.toLocalDate(),
                location = location,
                amount = grossAmount,
                energyKWh = energyKwh
            )

            if (!existingKeys.add(dedupeKey)) {
                skippedRows += 1
                return@forEach
            }

            val notes = buildList {
                add("Imported from the official Tesla Supercharging CSV.")
                if (invoiceNumber.isNotBlank()) add("Invoice: $invoiceNumber")
                if (vehicleName.isNotBlank()) add("Vehicle: $vehicleName")
                if (vin.isNotBlank()) add("VIN: $vin")
                if (pricePerKwh != null) add("Price per kWh: ${"%.4f".format(Locale.US, pricePerKwh)}")
                if (vatAmount != null) add("VAT: ${"%.2f".format(Locale.US, vatAmount)}")
                if (description.isNotBlank()) add(description)
            }.joinToString("\n")

            entriesStore.saveEntry(
                ExpenseEntry(
                    title = "Tesla Supercharging",
                    category = EntryCategory.Charging,
                    amount = grossAmount,
                    energyKWh = energyKwh,
                    date = startedAt.toLocalDate(),
                    location = location,
                    vehicleId = vehicleId,
                    notes = notes
                )
            )
            importedEntries += 1
        }

        return TeslaOfficialCsvImportResult(
            importedEntries = importedEntries,
            skippedRows = skippedRows,
            backfilledKwhRows = backfilledRows,
            autoCreatedVehicles = autoCreatedVehicles
        )
    }

    fun chargingForecastSummary(): String {
        val sessions = teslaFiStore.sessions.value
        if (sessions.isEmpty()) {
            val chargingEntries = entriesStore.entries.value.filter { it.category == EntryCategory.Charging }
            if (chargingEntries.isEmpty()) return "No charging sessions yet."
            val averageSpend = chargingEntries.map { it.amount }.average()
            return "${"%.2f".format(Locale.US, averageSpend)} average spend per charging entry, based on your imported and manual charging history."
        }
        val avgSession = sessions.map { it.energyAddedKWh }.average()
        return "${"%.1f".format(Locale.US, avgSession)} kWh average per session, with fast charging used ${(sessions.count { it.isSupercharger }.toFloat() / sessions.size * 100f).roundToInt()}% of the time."
    }

    private fun buildDashboardInsights(
        activeVehicle: VehicleProfile?,
        sessions: List<ChargingSession>,
        entries: List<ExpenseEntry>
    ): List<DashboardInsight> {
        if (activeVehicle == null && entries.isEmpty() && sessions.isEmpty()) {
            return listOf(
                DashboardInsight(
                    title = "Start with your vehicle",
                    body = "Add your car in the Garage tab to personalize charging imports, costs, and dashboard summaries.",
                    scoreLabel = "Setup"
                ),
                DashboardInsight(
                    title = "Import Tesla billing history",
                    body = "The charging import center can now bring in the official Tesla Supercharging CSV and turn each billed stop into a real expense entry.",
                    scoreLabel = "Ready"
                )
            )
        }

        val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
        val fastChargeSpend = chargingEntries
            .filter { it.location.contains("tesla", ignoreCase = true) || it.location.contains("supercharg", ignoreCase = true) }
            .sumOf { it.amount }
        val averageEntrySpend = chargingEntries.map { it.amount }.average()
        val sessionAverage = sessions.map { it.energyAddedKWh }.average()

        return buildList {
            if (chargingEntries.isNotEmpty()) {
                add(
                    DashboardInsight(
                        title = "Charging ledger is live",
                        body = "${chargingEntries.size} charging expense ${if (chargingEntries.size == 1) "entry has" else "entries have"} been recorded${if (fastChargeSpend > 0.0) ", including ${"%.2f".format(Locale.US, fastChargeSpend)} in Tesla Supercharging." else "."}",
                        scoreLabel = "Tracking"
                    )
                )
            }
            if (sessionAverage.isFinite()) {
                add(
                    DashboardInsight(
                        title = "Average energy per session",
                        body = "${"%.1f".format(Locale.US, sessionAverage)} kWh per logged session gives you a more grounded baseline for forecasting and cost comparisons.",
                        scoreLabel = "Live"
                    )
                )
            } else if (averageEntrySpend.isFinite()) {
                add(
                    DashboardInsight(
                        title = "Average charging spend",
                        body = "${"%.2f".format(Locale.US, averageEntrySpend)} per charging entry is enough to start spotting higher-cost fast-charging stops.",
                        scoreLabel = "Monitor"
                    )
                )
            }
            if (isEmpty()) {
                add(
                    DashboardInsight(
                        title = "Waiting on charging data",
                        body = "Once you add a vehicle or import charging history, this dashboard will replace setup guidance with real trends.",
                        scoreLabel = "Setup"
                    )
                )
            }
        }
    }
}

private fun percentLabel(value: Double): String = "${(value * 100.0).roundToInt()}%"

private fun Double.rateCurrency(): String = "$" + String.format(Locale.US, "%.2f", this)

private fun Double.oneDecimalValue(): String = String.format(Locale.US, "%.1f", this)

class AppStartupCoordinator {
    private val _didWarmup = MutableStateFlow(true)
    val didWarmup: StateFlow<Boolean> = _didWarmup
}
