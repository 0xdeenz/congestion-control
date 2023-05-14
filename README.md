## Congestion Control

Implements the circuits for the congestion control algorithms as described in "Verifiable Computation for Embedded Blockchains" onto a simple base rollup logic found in [`base_state_update.circom`](./circuits/base/base_state_update.circom). This base template outsources the computation of the account leaf, the different implementations that build on top each define a different account leaf object depending on the congestion control algorithm being enforced. These are:
- [Initial Congestion](./circuits/initial_congestion_state_update.circom)
- [Bounding Congestion](./circuits/bounding_congestion_state_update.circom)
- [Rolling Congestion](./circuits/rolling_congestion_state_update.circom)
- [Sliding Congestion](./circuits/sliding_congestion_state_update.circom)

## Installing dependencies

Run `npm i` or `yarn` to install the `circomlib` library of circom circuits.