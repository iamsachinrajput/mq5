# Scenario-Based Lot Sizing System

## Overview
The new lot sizing system replaces the old single-method approach with a sophisticated scenario-based system that automatically adjusts lot sizes based on market conditions and position distribution.

## System Architecture

### 7 Market Scenarios

1. **Boundary Orders** (`LOT_SCENARIO_BOUNDARY`)
   - **When**: Placing the topmost BUY or bottommost SELL order
   - **Detection**: No orders exist above (for BUY) or below (for SELL) the current level
   - **Typical Use**: Conservative lot sizes since these are extremes
   - **Default Method**: `LOT_CALC_BASE` (base lot size only)

2. **Direction Orders** (`LOT_SCENARIO_DIRECTION`)
   - **When**: Placing orders in the direction of price movement
   - **Detection**: Order is opposite to the accumulated losing side
     - If more SELL orders in loss → movement is UP → BUY is direction order
     - If more BUY orders in loss → movement is DOWN → SELL is direction order
   - **Typical Use**: Aggressive lot sizes to catch potential reversals
   - **Default Method**: `LOT_CALC_GLO` (base * number of orders in loss)

3. **Counter-Direction Orders** (`LOT_SCENARIO_COUNTER`)
   - **When**: Placing orders against price movement
   - **Detection**: Order is same as the accumulated losing side
   - **Typical Use**: Conservative to limit exposure against the trend
   - **Default Method**: `LOT_CALC_BASE`

4. **More Profit Than Loss** (`LOT_SCENARIO_GPO_MORE`)
   - **When**: More orders are in profit than in loss (GPO > GLO)
   - **Detection**: Count of profitable orders > count of losing orders
   - **Typical Use**: Conservative since market is favorable
   - **Default Method**: `LOT_CALC_BASE`

5. **More Loss Than Profit** (`LOT_SCENARIO_GLO_MORE`)
   - **When**: More orders are in loss than in profit (GLO > GPO)
   - **Detection**: Count of losing orders > count of profitable orders
   - **Typical Use**: Aggressive to recover losses
   - **Default Method**: `LOT_CALC_GLO`

6. **Centered Position** (`LOT_SCENARIO_CENTERED`)
   - **When**: Orders are balanced between BUY and SELL sides
   - **Detection**: |BUY count - SELL count| ≤ CenteredThreshold
   - **Typical Use**: Balanced approach, can scale with total positions
   - **Default Method**: `LOT_CALC_BASE`

7. **Sided Position** (`LOT_SCENARIO_SIDED`)
   - **When**: Orders are imbalanced but not at boundary
   - **Detection**: |BUY count - SELL count| > CenteredThreshold
   - **Typical Use**: Rebalancing lot sizes to even out exposure
   - **Default Method**: `LOT_CALC_GLO`

### 6 Calculation Methods

Each scenario can use one of these methods:

1. **LOT_CALC_BASE** (0)
   - Formula: `BaseLotSize`
   - Use: Conservative, fixed lot size

2. **LOT_CALC_GLO** (1)
   - Formula: `BaseLotSize * GLO_count`
   - Use: Scales with orders in loss (martingale-like)

3. **LOT_CALC_GPO** (2)
   - Formula: `BaseLotSize * GPO_count`
   - Use: Scales with orders in profit

4. **LOT_CALC_GLO_GPO_DIFF** (3)
   - Formula: `BaseLotSize * |GLO - GPO|`
   - Use: Scales with difference between loss and profit orders

5. **LOT_CALC_TOTAL_ORDERS** (4)
   - Formula: `BaseLotSize * total_order_count`
   - Use: Scales with total positions regardless of P/L

6. **LOT_CALC_BUY_SELL_DIFF** (5)
   - Formula: `BaseLotSize * |buy_count - sell_count|`
   - Use: Scales with directional imbalance

## Configuration Parameters

```mql5
// Scenario-Based Lot Sizing
input ENUM_LOT_CALC_METHOD LotCalc_Boundary = LOT_CALC_BASE;      // Case 1
input ENUM_LOT_CALC_METHOD LotCalc_Direction = LOT_CALC_GLO;      // Case 2
input ENUM_LOT_CALC_METHOD LotCalc_Counter = LOT_CALC_BASE;       // Case 3
input ENUM_LOT_CALC_METHOD LotCalc_GPO_More = LOT_CALC_BASE;      // Case 4
input ENUM_LOT_CALC_METHOD LotCalc_GLO_More = LOT_CALC_GLO;       // Case 5
input ENUM_LOT_CALC_METHOD LotCalc_Centered = LOT_CALC_BASE;      // Case 6
input ENUM_LOT_CALC_METHOD LotCalc_Sided = LOT_CALC_GLO;          // Case 7
input int CenteredThreshold = 2;  // Max buy/sell difference for centered
```

## Implementation Details

### Function Flow

1. **CalculateNextLots()** - Main entry point
   - Gets current price level
   - Calls DetectLotScenario() for BUY
   - Calls DetectLotScenario() for SELL
   - Applies appropriate methods
   - Normalizes lot sizes
   - Logs scenario and method used

2. **DetectLotScenario(orderType, level)** - Scenario detection
   - Counts orders by type and P/L status
   - Checks boundary conditions
   - Evaluates centered/sided thresholds
   - Compares GLO vs GPO
   - Determines direction vs counter-direction
   - Returns scenario number (0-6)

3. **GetMethodForScenario(scenario)** - Method lookup
   - Maps scenario number to configured method
   - Returns enum value for calculation

4. **ApplyLotMethod(method)** - Calculation
   - Counts all orders by P/L and type
   - Applies formula based on method
   - Returns calculated lot size

5. **NormalizeLotSize(lotSize)** - Normalization
   - Ensures lot meets broker requirements
   - Rounds to step size
   - Clamps to min/max limits

### Scenario Detection Priority

The system checks scenarios in this order:

1. **Boundary** (highest priority - specific condition)
2. **Centered** (structural - balanced distribution)
3. **Sided** (structural - imbalanced distribution)
4. **GPO > GLO** (P/L based - net profit state)
5. **GLO > GPO** (P/L based - net loss state)
6. **Direction/Counter** (directional - based on accumulation)

This priority ensures the most specific conditions are detected first, with more general conditions as fallbacks.

## Example Scenarios

### Example 1: Recovery Mode
**Situation**: 10 BUY orders in loss, 2 SELL orders in profit
- Scenario: GLO_MORE (GLO=10, GPO=2)
- Method: LOT_CALC_GLO
- Calculation: 0.01 * 10 = 0.10 lots
- Result: Aggressive sizing to recover losses

### Example 2: Boundary Order
**Situation**: Placing topmost BUY with no BUYs above
- Scenario: BOUNDARY
- Method: LOT_CALC_BASE
- Calculation: 0.01 lots
- Result: Conservative at extremes

### Example 3: Balanced Trading
**Situation**: 5 BUYs and 6 SELLs (difference = 1, threshold = 2)
- Scenario: CENTERED
- Method: LOT_CALC_BASE
- Calculation: 0.01 lots
- Result: Steady sizing when balanced

### Example 4: Direction Trading
**Situation**: 8 SELL orders in loss, placing new BUY
- Scenario: DIRECTION (movement is UP)
- Method: LOT_CALC_GLO
- Calculation: 0.01 * 8 = 0.08 lots
- Result: Aggressive in trend direction

## Migration from Old System

### Old System
- Single global lot calculation method
- 5 hardcoded methods (MaxOrders, OrderDiff, HedgeSame, FixedLevels, GLO-Based)
- No context awareness
- Same lot size for all scenarios

### New System
- 7 distinct scenarios
- 6 flexible calculation methods
- Automatic scenario detection
- Customizable method per scenario

### Benefits
1. **Granular Control**: Different strategies for different market conditions
2. **Context Awareness**: Lot sizes adapt to position distribution
3. **Risk Management**: Conservative at boundaries, aggressive in recovery
4. **Flexibility**: 42 possible configurations (7 scenarios × 6 methods)
5. **Logging**: Clear visibility into which scenario and method is active

## Configuration Strategies

### Conservative Profile
```mql5
LotCalc_Boundary = LOT_CALC_BASE
LotCalc_Direction = LOT_CALC_BASE
LotCalc_Counter = LOT_CALC_BASE
LotCalc_GPO_More = LOT_CALC_BASE
LotCalc_GLO_More = LOT_CALC_BASE
LotCalc_Centered = LOT_CALC_BASE
LotCalc_Sided = LOT_CALC_BASE
```
Result: Fixed base lot size in all situations

### Aggressive Recovery Profile
```mql5
LotCalc_Boundary = LOT_CALC_BASE
LotCalc_Direction = LOT_CALC_GLO
LotCalc_Counter = LOT_CALC_BASE
LotCalc_GPO_More = LOT_CALC_BASE
LotCalc_GLO_More = LOT_CALC_GLO
LotCalc_Centered = LOT_CALC_BASE
LotCalc_Sided = LOT_CALC_GLO
```
Result: Aggressive when in loss, conservative when profitable

### Balanced Scaling Profile
```mql5
LotCalc_Boundary = LOT_CALC_BASE
LotCalc_Direction = LOT_CALC_TOTAL_ORDERS
LotCalc_Counter = LOT_CALC_BASE
LotCalc_GPO_More = LOT_CALC_TOTAL_ORDERS
LotCalc_GLO_More = LOT_CALC_TOTAL_ORDERS
LotCalc_Centered = LOT_CALC_TOTAL_ORDERS
LotCalc_Sided = LOT_CALC_BUY_SELL_DIFF
```
Result: Scales with position count, rebalances when sided

## Logging Output

The system provides detailed logging:

```
Lot Calc: BUY Scenario=Direction Method=GLO Lot=0.08 | SELL Scenario=Counter Method=Base Lot=0.01
```

This shows:
- BUY order detected as Direction scenario
- Using GLO method (base * 8 GLO = 0.08)
- SELL order detected as Counter scenario
- Using Base method (0.01)

## Notes

- Scenario detection runs independently for BUY and SELL
- Same market conditions can trigger different scenarios for different order types
- Trail mode can override scenario-based lots (when trail is active)
- CenteredThreshold parameter controls the boundary between Centered and Sided scenarios
- All lot sizes are normalized to broker requirements (min/max/step)
