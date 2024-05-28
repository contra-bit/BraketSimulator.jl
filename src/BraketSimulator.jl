module BraketSimulator

using Braket,
    Braket.Observables,
    Dates,
    LinearAlgebra,
    StaticArrays,
    StatsBase,
    Combinatorics,
    UUIDs,
    JSON3,
    Random,
    PrecompileTools

import Braket:
    Instruction,
    AbstractBraketSimulator,
    Program,
    OpenQasmProgram,
    ir_typ,
    apply_gate!,
    apply_noise!,
    qubit_count,
    I,
    simulate,
    device_id,
    bind_value!


export StateVector, StateVectorSimulator, DensityMatrixSimulator, evolve!, simulate, U, MultiQubitPhaseShift, MultiRZ

const StateVector{T} = Vector{T}
const DensityMatrix{T} = Matrix{T}
const AbstractStateVector{T} = AbstractVector{T}
const AbstractDensityMatrix{T} = AbstractMatrix{T}

abstract type AbstractSimulator <: Braket.AbstractBraketSimulator end
Braket.name(s::AbstractSimulator) = device_id(s)
ap_size(shots::Int, qubit_count::Int) = (shots > 0 && qubit_count < 30) ? 2^qubit_count : 0

include("validation.jl")
include("custom_gates.jl")
include("inverted_gates.jl")
include("pow_gates.jl")
include("gate_kernels.jl")
include("noise_kernels.jl")
include("Quasar.jl")

using .Quasar

const BuiltinGates = merge(Braket.StructTypes.subtypes(Braket.Gate), custom_gates) 

const OBS_LIST = (Observables.X(), Observables.Y(), Observables.Z())
const CHUNK_SIZE = 2^10

parse_program(d, program, shots::Int) = throw(MethodError(parse_program, (d, program, shots)))

function _index_to_endian_bits(ix::Int, qubit_count::Int)
    bits = Vector{Int}(undef, qubit_count)
    for qubit = 0:qubit_count-1
        bit = (ix >> qubit) & 1
        bits[end-qubit] = bit
    end
    return bits
end

function _formatted_measurements(simulator::D, measured_qubits::Vector{Int}=collect(0:qubit_count(simulator)-1)) where {D<:AbstractSimulator}
    sim_samples = samples(simulator)
    n_qubits    = qubit_count(simulator)
    formatted   = [_index_to_endian_bits(sample, n_qubits)[measured_qubits .+ 1] for sample in sim_samples]
    return formatted
end

function _bundle_results(
    results::Vector{Braket.ResultTypeValue},
    circuit_ir::Program,
    simulator::D;
    measured_qubits::Vector{Int} = collect(0:qubit_count(simulator)-1)
) where {D<:AbstractSimulator}
    task_mtd = Braket.TaskMetadata(
        Braket.header_dict[Braket.TaskMetadata],
        string(uuid4()),
        simulator.shots,
        device_id(simulator),
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
    )
    addl_mtd = Braket.AdditionalMetadata(
        circuit_ir,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
    )
    formatted_samples = simulator.shots > 0 ? _formatted_measurements(simulator, measured_qubits) : Vector{Int}[]
    return Braket.GateModelTaskResult(
        Braket.header_dict[Braket.GateModelTaskResult],
        formatted_samples,
        nothing,
        results,
        measured_qubits,
        task_mtd,
        addl_mtd,
    )
end

function _bundle_results(
    results::Vector{Braket.ResultTypeValue},
    circuit_ir::OpenQasmProgram,
    simulator::D;
    measured_qubits::Vector{Int} = collect(0:qubit_count(simulator)-1)
) where {D<:AbstractSimulator}
    task_mtd = Braket.TaskMetadata(
        Braket.header_dict[Braket.TaskMetadata],
        string(uuid4()),
        simulator.shots,
        device_id(simulator),
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
    )
    addl_mtd = Braket.AdditionalMetadata(
        circuit_ir,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
    )
    formatted_samples = simulator.shots > 0 ? _formatted_measurements(simulator, measured_qubits) : Vector{Int}[]
    return Braket.GateModelTaskResult(
        Braket.header_dict[Braket.GateModelTaskResult],
        formatted_samples,
        nothing,
        results,
        measured_qubits,
        task_mtd,
        addl_mtd,
    )
end

function _generate_results(
    results::Vector{<:Braket.AbstractProgramResult},
    result_types::Vector,
    simulator::D,
) where {D<:AbstractSimulator}
    result_values = map(result_type -> calculate(result_type, simulator), result_types)
    result_values =
        [val isa Matrix ? Braket.complex_matrix_to_ir(val) : val for val in result_values]
    return map(zip(results, result_values)) do (result, result_value)
        Braket.ResultTypeValue(result, result_value)
    end
end

_translate_result_type(r::Braket.IR.Amplitude, qc::Int)     = Braket.Amplitude(r.states)
_translate_result_type(r::Braket.IR.StateVector, qc::Int)   = Braket.StateVector()
# The IR result types support `nothing` as a valid option for the `targets` field,
# however `Braket.jl`'s `Result`s represent this with an empty `QubitSet` for type
# stability reasons. Here we take a `nothing` value for `targets` and translate it
# to apply to all qubits.
_translate_result_type(r::Braket.IR.DensityMatrix, qc::Int) = isnothing(r.targets) ? Braket.DensityMatrix(collect(0:qc-1)) : Braket.DensityMatrix(r.targets)
_translate_result_type(r::Braket.IR.Probability, qc::Int)   = isnothing(r.targets) ? Braket.Probability(collect(0:qc-1)) : Braket.Probability(r.targets)
function _translate_result_type(r::Braket.IR.Expectation, qc::Int)
    targets = isnothing(r.targets) ? collect(0:qc-1) : r.targets
    obs     = Braket.StructTypes.constructfrom(Braket.Observables.Observable, r.observable)
    Braket.Expectation(obs, QubitSet(targets))
end
function _translate_result_type(r::Braket.IR.Variance, qc::Int)
    targets = isnothing(r.targets) ? collect(0:qc-1) : r.targets
    obs     = Braket.StructTypes.constructfrom(Braket.Observables.Observable, r.observable)
    Braket.Variance(obs, QubitSet(targets))
end
function _translate_result_type(r::Braket.IR.Sample, qc::Int)
    targets = isnothing(r.targets) ? collect(0:qc-1) : r.targets
    obs     = Braket.StructTypes.constructfrom(Braket.Observables.Observable, r.observable)
    Braket.Sample(obs, QubitSet(targets))
end

function _translate_result_types(
    results::Vector{Braket.AbstractProgramResult},
    qubit_count::Int,
)
    return map(result->_translate_result_type(result, qubit_count), results)
end

function _compute_exact_results(d::AbstractSimulator, program::Program, qc::Int)
    result_types = _translate_result_types(program.results, qc)
    _validate_result_types_qubits_exist(result_types, qc)
    return _generate_results(program.results, result_types, d)
end

"""
    simulate(simulator::AbstractSimulator, circuit_ir; shots::Int = 0, kwargs...) -> GateModelTaskResult

Simulate the evolution of a statevector or density matrix using the passed in `simulator`.
The instructions to apply (gates and noise channels) and measurements to make are
encoded in `circuit_ir`. Supported IR formats are `OpenQASMProgram` (OpenQASM3)
and `Program` (JAQCD). Returns a `GateModelTaskResult` containing the individual shot
measurements (if `shots > 0`), final calculated results, circuit IR, and metadata
about the task.
"""
function simulate(
    simulator::AbstractSimulator,
    circuit_ir::OpenQasmProgram;
    shots::Int = 0,
    kwargs...,
)
    inputs  = isnothing(circuit_ir.inputs) ? Dict{String, Float64}() : Dict{String, Any}(k=>v for (k,v) in circuit_ir.inputs)
    circuit = Circuit(circuit_ir.source, inputs)
    shots > 0 && Braket.basis_rotation_instructions!(circuit)
    program = Program(circuit) 
    n_qubits = qubit_count(program)
    _validate_ir_results_compatibility(simulator, program.results, Val(:JAQCD))
    _validate_ir_instructions_compatibility(simulator, program, Val(:JAQCD))
    _validate_shots_and_ir_results(shots, program.results, n_qubits)
    operations = program.instructions
    if shots > 0 && !isempty(program.basis_rotation_instructions)
        operations = vcat(operations, program.basis_rotation_instructions)
    end
    _validate_operation_qubits(operations)
    reinit!(simulator, n_qubits, shots)
    stats = @timed begin
        simulator = evolve!(simulator, operations)
    end
    @debug "Time for evolution: $(stats.time)"
    results = shots == 0 && !isempty(program.results) ? _compute_exact_results(simulator, program, n_qubits) : [Braket.ResultTypeValue(result_type, 0.0) for result_type in program.results]
    measured_qubits = get(kwargs, :measured_qubits, collect(0:n_qubits-1))
    isempty(measured_qubits) && (measured_qubits = collect(0:n_qubits-1))
    stats   = @timed _bundle_results(results, circuit_ir, simulator; measured_qubits=measured_qubits)
    @debug "Time for results bundling: $(stats.time)"
    res = stats.value
    return res
end

function simulate(
    simulator::AbstractSimulator,
    circuit_ir::Program,
    qubit_count::Int;
    shots::Int = 0,
    kwargs...,
)
    _validate_ir_results_compatibility(simulator, circuit_ir.results, Val(:JAQCD))
    _validate_ir_instructions_compatibility(simulator, circuit_ir, Val(:JAQCD))
    _validate_shots_and_ir_results(shots, circuit_ir.results, qubit_count)
    operations::Vector{Instruction} = circuit_ir.instructions
    if shots > 0 && !isempty(circuit_ir.basis_rotation_instructions)
        operations = vcat(operations, circuit_ir.basis_rotation_instructions)
    end
    inputs = get(kwargs, :inputs, Dict{String,Float64}())
    symbol_inputs = Dict{Symbol,Number}(Symbol(k) => v for (k, v) in inputs)
    operations = [bind_value!(Instruction(operation), symbol_inputs) for operation in operations]
    _validate_operation_qubits(operations)
    reinit!(simulator, qubit_count, shots)
    stats = @timed begin
        simulator = evolve!(simulator, operations)
    end
    @debug "Time for evolution: $(stats.time)"
    results = shots == 0 && !isempty(circuit_ir.results) ? _compute_exact_results(simulator, circuit_ir, qubit_count) : Braket.ResultTypeValue[]
    measured_qubits = get(kwargs, :measured_qubits, collect(0:qubit_count-1))
    isempty(measured_qubits) && (measured_qubits = collect(0:qubit_count-1))
    stats = @timed _bundle_results(results, circuit_ir, simulator; measured_qubits=measured_qubits)
    @debug "Time for results bundling: $(stats.time)"
    res = stats.value
    return res
end

include("observables.jl")
include("result_types.jl")
include("properties.jl")
include("sv_simulator.jl")
include("dm_simulator.jl")
#include("precompile.jl")

function __init__()
    Braket._simulator_devices[]["braket_dm_v2"] =
        DensityMatrixSimulator{ComplexF64,DensityMatrix{ComplexF64}}
    Braket._simulator_devices[]["braket_sv_v2"] =
        StateVectorSimulator{ComplexF64,StateVector{ComplexF64}}
end

@setup_workload begin
    custom_qasm = """
               int[8] two = 2;
               gate x a { U(π, 0, π) a; }
               gate cx c, a {
                   pow(1) @ ctrl @ x c, a;
               }
               gate cxx_1 c, a {
                   pow(two) @ cx c, a;
               }
               gate cxx_2 c, a {
                   pow(1/2) @ pow(4) @ cx c, a;
               }
               gate cxxx c, a {
                   pow(1) @ pow(two) @ cx c, a;
               }

               qubit q1;
               qubit q2;
               qubit q3;
               qubit q4;
               qubit q5;

               pow(1/2) @ x q1;       // half flip
               pow(1/2) @ x q1;       // half flip
               cx q1, q2;   // flip
               cxx_1 q1, q3;    // don't flip
               cxx_2 q1, q4;    // don't flip
               cnot q1, q5;    // flip
               x q3;       // flip
               x q4;       // flip

               s q1;   // sqrt z
               s q1;   // again
               inv @ z q1; // inv z
               """;
    noise_qasm = """
        qubit[2] qs;

        #pragma braket noise bit_flip(.5) qs[1]
        #pragma braket noise phase_flip(.5) qs[0]
        #pragma braket noise pauli_channel(.1, .2, .3) qs[0]
        #pragma braket noise depolarizing(.5) qs[0]
        #pragma braket noise two_qubit_depolarizing(.9) qs
        #pragma braket noise two_qubit_depolarizing(.7) qs[1], qs[0]
        #pragma braket noise two_qubit_dephasing(.6) qs
        #pragma braket noise amplitude_damping(.2) qs[0]
        #pragma braket noise generalized_amplitude_damping(.2, .3)  qs[1]
        #pragma braket noise phase_damping(.4) qs[0]
        #pragma braket noise kraus([[0.9486833im, 0], [0, 0.9486833im]], [[0, 0.31622777], [0.31622777, 0]]) qs[0]
        #pragma braket noise kraus([[0.9486832980505138, 0, 0, 0], [0, 0.9486832980505138, 0, 0], [0, 0, 0.9486832980505138, 0], [0, 0, 0, 0.9486832980505138]], [[0, 0.31622776601683794, 0, 0], [0.31622776601683794, 0, 0, 0], [0, 0, 0, 0.31622776601683794], [0, 0, 0.31622776601683794, 0]]) qs[{1, 0}]
        """
    unitary_qasm = """
        qubit[3] q;

        x q[0];
        h q[1];

        // unitary pragma for t gate
        #pragma braket unitary([[1.0, 0], [0, 0.70710678 + 0.70710678im]]) q[0]
        ti q[0];

        // unitary pragma for h gate (with phase shift)
        #pragma braket unitary([[0.70710678im, 0.70710678im], [0 - -0.70710678im, -0.0 - 0.70710678im]]) q[1]
        gphase(-π/2) q[1];
        h q[1];

        // unitary pragma for ccnot gate
        #pragma braket unitary([[1.0, 0, 0, 0, 0, 0, 0, 0], [0, 1.0, 0, 0, 0, 0, 0, 0], [0, 0, 1.0, 0, 0, 0, 0, 0], [0, 0, 0, 1.0, 0, 0, 0, 0], [0, 0, 0, 0, 1.0, 0, 0, 0], [0, 0, 0, 0, 0, 1.0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 1.0], [0, 0, 0, 0, 0, 0, 1.0, 0]]) q
        """
    sv_adder_qasm = """
        OPENQASM 3;

        input uint[4] a_in;
        input uint[4] b_in;

        gate majority a, b, c {
            cnot c, b;
            cnot c, a;
            ccnot a, b, c;
        }

        gate unmaj a, b, c {
            ccnot a, b, c;
            cnot c, a;
            cnot a, b;
        }

        qubit cin;
        qubit[4] a;
        qubit[4] b;
        qubit cout;

        // set input states
        for int[8] i in [0: 3] {
          if(bool(a_in[i])) x a[i];
          if(bool(b_in[i])) x b[i];
        }

        // add a to b, storing result in b
        majority cin, b[3], a[3];
        for int[8] i in [3: -1: 1] { majority a[i], b[i - 1], a[i - 1]; }
        cnot a[0], cout;
        for int[8] i in [1: 3] { unmaj a[i], b[i - 1], a[i - 1]; }
        unmaj cin, b[3], a[3];

        // todo: subtle bug when trying to get a result type for both at once
        #pragma braket result probability cout, b
        #pragma braket result probability cout
        #pragma braket result probability b
        """
    @compile_workload begin
        using Braket, BraketSimulator, BraketSimulator.Quasar
        simulator = StateVectorSimulator(5, 0)
        oq3_program = Braket.OpenQasmProgram(Braket.header_dict[Braket.OpenQasmProgram], custom_qasm, nothing)
        simulate(simulator, oq3_program, shots=100)
        
        simulator = DensityMatrixSimulator(2, 0)
        oq3_program = Braket.OpenQasmProgram(Braket.header_dict[Braket.OpenQasmProgram], noise_qasm, nothing)
        simulate(simulator, oq3_program, shots=100)
        
        simulator = StateVectorSimulator(3, 0)
        oq3_program = Braket.OpenQasmProgram(Braket.header_dict[Braket.OpenQasmProgram], unitary_qasm, nothing)
        simulate(simulator, oq3_program, shots=100)
        
        simulator = StateVectorSimulator(6, 0)
        oq3_program = Braket.OpenQasmProgram(Braket.header_dict[Braket.OpenQasmProgram], sv_adder_qasm, Dict("a_in"=>3, "b_in"=>7))
        simulate(simulator, oq3_program, shots=0)
    end
end

end # module BraketSimulator