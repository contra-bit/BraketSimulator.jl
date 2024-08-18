```@meta
CurrentModule = BraketSimulator
```

## Circuit Quickstart 

To create a quantum circuit directly from OpenQASM code, you can use the `Circuit` function from the `BraketSimulator.Quasar` module.

```@example
using BraketSimulator.Quasar
Circuit("""
        qubit[2] q;
        bit[2] c;

        h q[0];
        cz q[0], q[1];
        measure q -> c;
        """)
```

# Circuits
Circuits are made up of *instructions* (operations to apply to the qubits -- [gates](gates.md) and [noises](noises.md)) and *result types* ([results](results.md)).
OpenQASM3 programs are parsed to circuits which are then run on the simulator.

```@docs
BraketSimulator.Circuit
BraketSimulator.Operator
BraketSimulator.QuantumOperator
BraketSimulator.FreeParameter
BraketSimulator.Measure
BraketSimulator.Instruction
BraketSimulator.QubitSet
BraketSimulator.Qubit
BraketSimulator.qubit_count
BraketSimulator.qubits
BraketSimulator.basis_rotation_instructions!
```
