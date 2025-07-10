smooth-interest-rate-model/
├── contracts/
│   ├── core/
│   │   ├── SmoothInterestRateModel.sol
│   │   ├── InterestRateStorage.sol
│   │   └── RateCalculationEngine.sol
│   ├── libraries/
│   │   ├── SineLibrary.sol
│   │   ├── FixedPointMath.sol
│   │   └── RateUtils.sol
│   ├── interfaces/
│   │   ├── IInterestRateModel.sol
│   │   ├── IRateCalculator.sol
│   │   └── IRateOracle.sol
│   ├── utils/
│   │   ├── Governable.sol
│   │   ├── Pausable.sol
│   │   └── EmergencyActions.sol
│   └── mocks/
│       ├── MockLendingPool.sol
│       └── MockPriceOracle.sol
├── scripts/
│   ├── deploy/
│   │   ├── 01_deploy_libraries.js
│   │   ├── 02_deploy_core.js
│   │   └── 03_initialize_system.js
│   ├── utils/
│   │   ├── verify.js
│   │   └── upgrade.js
│   └── simulations/
│       ├── rate_simulation.js
│       └── stress_test.js
├── test/
│   ├── unit/
│   │   ├── SineLibrary.test.js
│   │   ├── RateCalculation.test.js
│   │   └── Smoothing.test.js
│   ├── integration/
│   │   ├── FullSystem.test.js
│   │   └── LendingIntegration.test.js
│   └── fuzzing/
│       └── RateFuzzing.test.js
├── docs/
│   ├── architecture.md
│   ├── mathematical_model.md
│   ├── deployment_guide.md
│   └── api_reference.md
├── config/
│   ├── networks.js
│   ├── parameters.js
│   └── deployment_config.js
├── hardhat.config.js
├── package.json
└── README.md