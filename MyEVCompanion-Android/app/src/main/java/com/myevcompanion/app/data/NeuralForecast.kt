package com.myevcompanion.app.data

import java.util.Locale
import java.util.Random
import kotlin.math.abs
import kotlin.math.sqrt

data class ChargingForecastInput(
    val sessionIndex: Int,
    val provider: String,
    val weekdayValue: Int,
    val energyKwh: Double,
    val cost: Double,
    val isHome: Boolean
) {
    val costPerKwh: Double
        get() = if (energyKwh > 0.0) cost / energyKwh else 0.0
}

data class ChargingNeuralForecast(
    val predictedEnergyKwh: Double,
    val predictedCost: Double,
    val predictedRatePerKwh: Double,
    val energyRmse: Double,
    val costRmse: Double,
    val rateRmse: Double,
    val reinforcementReward: Double,
    val reinforcementStageLabel: String,
    val summaryLabel: String,
    val modelLabel: String
)

private data class TrainingRow(
    val features: DoubleArray,
    val energyTarget: Double,
    val costTarget: Double,
    val rateTarget: Double
)

private data class TrainingStats(
    val maxIndex: Double,
    val providerOrder: List<String>,
    val meanEnergy: Double,
    val stdEnergy: Double,
    val meanCost: Double,
    val stdCost: Double,
    val meanRate: Double,
    val stdRate: Double
)

private class TinyDenseRegressor(
    inputSize: Int,
    hiddenSize: Int = 8,
    private val learningRate: Double = 0.035,
    private val epochs: Int = 900,
    private val reinforcementEpochs: Int = 180,
    seed: Long = 7L
) {
    private val random = Random(seed)
    private val hiddenWeights = Array(hiddenSize) {
        DoubleArray(inputSize) { (random.nextDouble() - 0.5) * 0.35 }
    }
    private val hiddenBias = DoubleArray(hiddenSize) { 0.0 }
    private val outputWeights = DoubleArray(hiddenSize) { (random.nextDouble() - 0.5) * 0.35 }
    private var outputBias = 0.0

    fun fit(samples: List<Pair<DoubleArray, Double>>) {
        if (samples.isEmpty()) return
        repeat(epochs) {
            samples.forEach { (features, target) -> trainStep(features, target) }
        }
    }

    fun reinforce(samples: List<Pair<DoubleArray, Double>>): Double {
        if (samples.isEmpty()) return 0.0

        var rewardTotal = 0.0
        var rewardCount = 0
        repeat(reinforcementEpochs) {
            samples.forEach { (features, target) ->
                val prediction = predict(features)
                val bestAction = policyActions.maxByOrNull { action ->
                    rewardFor(prediction + action, target, action)
                } ?: 0.0
                rewardTotal += rewardFor(prediction + bestAction, target, bestAction)
                rewardCount += 1
                trainStep(features, prediction + bestAction)
            }
        }

        return if (rewardCount == 0) 0.0 else rewardTotal / rewardCount.toDouble()
    }

    fun predict(features: DoubleArray): Double {
        val hidden = DoubleArray(hiddenWeights.size)
        for (hiddenIndex in hiddenWeights.indices) {
            var sum = hiddenBias[hiddenIndex]
            for (featureIndex in features.indices) {
                sum += hiddenWeights[hiddenIndex][featureIndex] * features[featureIndex]
            }
            hidden[hiddenIndex] = tanh(sum)
        }

        var output = outputBias
        for (hiddenIndex in hidden.indices) {
            output += outputWeights[hiddenIndex] * hidden[hiddenIndex]
        }
        return output
    }

    private fun trainStep(features: DoubleArray, target: Double) {
        val hiddenLinear = DoubleArray(hiddenWeights.size)
        val hidden = DoubleArray(hiddenWeights.size)
        for (hiddenIndex in hiddenWeights.indices) {
            var sum = hiddenBias[hiddenIndex]
            for (featureIndex in features.indices) {
                sum += hiddenWeights[hiddenIndex][featureIndex] * features[featureIndex]
            }
            hiddenLinear[hiddenIndex] = sum
            hidden[hiddenIndex] = tanh(sum)
        }

        var prediction = outputBias
        for (hiddenIndex in hidden.indices) {
            prediction += outputWeights[hiddenIndex] * hidden[hiddenIndex]
        }

        val error = prediction - target
        for (hiddenIndex in outputWeights.indices) {
            outputWeights[hiddenIndex] -= learningRate * error * hidden[hiddenIndex]
        }
        outputBias -= learningRate * error

        for (hiddenIndex in hiddenWeights.indices) {
            val tanhDerivative = 1.0 - (hidden[hiddenIndex] * hidden[hiddenIndex])
            val hiddenDelta = error * outputWeights[hiddenIndex] * tanhDerivative
            for (featureIndex in features.indices) {
                hiddenWeights[hiddenIndex][featureIndex] -= learningRate * hiddenDelta * features[featureIndex]
            }
            hiddenBias[hiddenIndex] -= learningRate * hiddenDelta
        }
    }

    private fun tanh(value: Double): Double = kotlin.math.tanh(value)

    private fun rewardFor(adjustedPrediction: Double, target: Double, action: Double): Double {
        val errorPenalty = abs(adjustedPrediction - target)
        val movementPenalty = abs(action) * 0.15
        return 1.0 - errorPenalty - movementPenalty
    }

    companion object {
        private val policyActions = doubleArrayOf(-0.12, -0.06, -0.025, 0.0, 0.025, 0.06, 0.12)
    }
}

object ChargingNeuralForecaster {
    fun forecast(observations: List<ChargingForecastInput>): ChargingNeuralForecast? {
        if (observations.size < 3) return null

        val stats = buildStats(observations)
        val rows = observations.map { observation ->
            TrainingRow(
                features = encodeFeatures(observation, stats),
                energyTarget = normalize(observation.energyKwh, stats.meanEnergy, stats.stdEnergy),
                costTarget = normalize(observation.cost, stats.meanCost, stats.stdCost),
                rateTarget = normalize(observation.costPerKwh, stats.meanRate, stats.stdRate)
            )
        }

        val featureCount = rows.firstOrNull()?.features?.size ?: return null
        val energyModel = TinyDenseRegressor(inputSize = featureCount, seed = 11L)
        val costModel = TinyDenseRegressor(inputSize = featureCount, seed = 23L)
        val rateModel = TinyDenseRegressor(inputSize = featureCount, seed = 37L)

        energyModel.fit(rows.map { it.features to it.energyTarget })
        costModel.fit(rows.map { it.features to it.costTarget })
        rateModel.fit(rows.map { it.features to it.rateTarget })

        val reinforcementReward = listOf(
            energyModel.reinforce(rows.map { it.features to it.energyTarget }),
            costModel.reinforce(rows.map { it.features to it.costTarget }),
            rateModel.reinforce(rows.map { it.features to it.rateTarget })
        ).average()

        val rmses = evaluateModels(rows, stats, energyModel, costModel, rateModel)
        val nextInput = observations.last().run {
            copy(sessionIndex = observations.size, weekdayValue = ((weekdayValue % 7) + 1))
        }
        val nextFeatures = encodeFeatures(nextInput, stats)

        val predictedEnergy = denormalize(energyModel.predict(nextFeatures), stats.meanEnergy, stats.stdEnergy).coerceAtLeast(0.0)
        val predictedCost = denormalize(costModel.predict(nextFeatures), stats.meanCost, stats.stdCost).coerceAtLeast(0.0)
        val predictedRate = denormalize(rateModel.predict(nextFeatures), stats.meanRate, stats.stdRate).coerceAtLeast(0.0)

        return ChargingNeuralForecast(
            predictedEnergyKwh = predictedEnergy,
            predictedCost = predictedCost,
            predictedRatePerKwh = predictedRate,
            energyRmse = rmses.first,
            costRmse = rmses.second,
            rateRmse = rmses.third,
            reinforcementReward = reinforcementReward,
            reinforcementStageLabel = buildReinforcementStageLabel(reinforcementReward),
            summaryLabel = buildSummaryLabel(rmses.second, observations.size),
            modelLabel = "1 hidden layer + RL fine-tune"
        )
    }

    private fun buildStats(observations: List<ChargingForecastInput>): TrainingStats {
        val providerOrder = observations.groupBy { it.provider }
            .entries
            .sortedByDescending { it.value.size }
            .map { it.key }
            .take(3)
        val energyValues = observations.map { it.energyKwh }
        val costValues = observations.map { it.cost }
        val rateValues = observations.map { it.costPerKwh }
        return TrainingStats(
            maxIndex = observations.maxOf { it.sessionIndex }.coerceAtLeast(1).toDouble(),
            providerOrder = providerOrder,
            meanEnergy = energyValues.average(),
            stdEnergy = energyValues.standardDeviation(),
            meanCost = costValues.average(),
            stdCost = costValues.standardDeviation(),
            meanRate = rateValues.average(),
            stdRate = rateValues.standardDeviation()
        )
    }

    private fun encodeFeatures(
        observation: ChargingForecastInput,
        stats: TrainingStats
    ): DoubleArray {
        val providerFeatures = stats.providerOrder.map { provider ->
            if (provider.equals(observation.provider, ignoreCase = true)) 1.0 else 0.0
        }
        val values = listOf(
            observation.sessionIndex / stats.maxIndex,
            observation.weekdayValue / 7.0,
            if (observation.weekdayValue >= 6) 1.0 else 0.0,
            if (observation.isHome) 1.0 else 0.0,
            observation.energyKwh / (stats.meanEnergy + stats.stdEnergy).coerceAtLeast(1.0),
            observation.costPerKwh / (stats.meanRate + stats.stdRate).coerceAtLeast(0.1)
        ) + providerFeatures
        return values.toDoubleArray()
    }

    private fun evaluateModels(
        rows: List<TrainingRow>,
        stats: TrainingStats,
        energyModel: TinyDenseRegressor,
        costModel: TinyDenseRegressor,
        rateModel: TinyDenseRegressor
    ): Triple<Double, Double, Double> {
        val energyErrors = mutableListOf<Double>()
        val costErrors = mutableListOf<Double>()
        val rateErrors = mutableListOf<Double>()

        rows.forEach { row ->
            val energyPrediction = denormalize(energyModel.predict(row.features), stats.meanEnergy, stats.stdEnergy)
            val costPrediction = denormalize(costModel.predict(row.features), stats.meanCost, stats.stdCost)
            val ratePrediction = denormalize(rateModel.predict(row.features), stats.meanRate, stats.stdRate)
            energyErrors += (energyPrediction - denormalize(row.energyTarget, stats.meanEnergy, stats.stdEnergy))
            costErrors += (costPrediction - denormalize(row.costTarget, stats.meanCost, stats.stdCost))
            rateErrors += (ratePrediction - denormalize(row.rateTarget, stats.meanRate, stats.stdRate))
        }

        return Triple(
            energyErrors.rmse(),
            costErrors.rmse(),
            rateErrors.rmse()
        )
    }

    private fun normalize(value: Double, mean: Double, std: Double): Double =
        if (std <= 0.0001) value - mean else (value - mean) / std

    private fun denormalize(value: Double, mean: Double, std: Double): Double =
        if (std <= 0.0001) value + mean else (value * std) + mean

    private fun List<Double>.standardDeviation(): Double {
        if (isEmpty()) return 1.0
        val mean = average()
        val variance = sumOf { value -> (value - mean) * (value - mean) } / size.toDouble()
        return sqrt(variance).coerceAtLeast(0.0001)
    }

    private fun List<Double>.rmse(): Double {
        if (isEmpty()) return 0.0
        return sqrt(sumOf { it * it } / size.toDouble())
    }

    private fun buildSummaryLabel(costRmse: Double, sampleCount: Int): String {
        val accuracyBand = when {
            costRmse <= 2.5 -> "Tight fit"
            costRmse <= 6.0 -> "Usable fit"
            else -> "Early fit"
        }
        return String.format(Locale.US, "%s • %d samples", accuracyBand, sampleCount)
    }

    private fun buildReinforcementStageLabel(reward: Double): String {
        val rewardBand = when {
            reward >= 0.86 -> "RL aligned"
            reward >= 0.72 -> "RL adapting"
            else -> "RL exploring"
        }
        return String.format(Locale.US, "%s • %.2f reward", rewardBand, reward.coerceIn(0.0, 1.0))
    }
}
