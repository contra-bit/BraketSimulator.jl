var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"DocTestSetup = quote using Braket, BraketSimulator end\nCurrentModule = BraketSimulator","category":"page"},{"location":"#BraketSimulator","page":"Home","title":"BraketSimulator","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package is a suite of Julia simulators of gate-based quantum circuits with (density matrix) and without (state vector) noise. It is designed to integrate with Amazon Braket, the quantum computing service from AWS. By default, it offers threaded CPU-based simulation of these circuits, and an optional package extension you can integrate with Python. To use the Python integration, you will need to install PythonCall.jl.","category":"page"},{"location":"","page":"Home","title":"Home","text":"See the Julia Pkg docs for more information about package extensions.","category":"page"},{"location":"","page":"Home","title":"Home","text":"If you wish to use this package from Python, see amazon-braket-simulator-v2, a Python package built on top of juliacall which will automatically install Julia and all necessary Julia packages in a Python virtual environment, set appropriate environment variables, and allow you to use these simulators from Python packages such as the Amazon Braket SDK or PennyLane.","category":"page"},{"location":"","page":"Home","title":"Home","text":"In order to achieve the best performance for your simulations, you should set -t auto when you launch Julia or set the environment variable JULIA_NUM_THREADS to auto (the number of CPU threads).","category":"page"},{"location":"#Quick-Start","page":"Home","title":"Quick Start","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"You can install this package and its dependencies using the Julia package manager. Note that the minimum supported Julia version is 1.9. If you need to install Julia itself, follow the directions on the JuliaLang website.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# install the package\nusing Pkg\nPkg.add(\"BraketSimulator\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"Then you can run a simulation of a simple GHZ state preparation circuit.","category":"page"},{"location":"","page":"Home","title":"Home","text":"note: Note\nTo simulate OpenQASM3 programs, you will need to load the Python extension BraketSimulatorPythonExt like so: using PythonCall, BraketSimulator. If you prefer not to install or use Python, make sure to set the default IRType for Braket.jl to JAQCD: Braket.IRType[] = :JAQCD. ","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using Braket, BraketSimulator\n\njulia> n_qubits = 10;\n\njulia> c = Circuit();\n\njulia> H(c, 0);\n\njulia> foreach(q->CNot(c, 0, q), 1:n_qubits-1);\n\njulia> Amplitude(c, [repeat(\"0\", n_qubits), repeat(\"1\", n_qubits)]);\n\njulia> sim = LocalSimulator(\"braket_sv_v2\"); # use the state vector simulator (without noise)\n\njulia> res = result(simulate(sim, ir(c, Val(:JAQCD)), shots=0));\n\njulia> res.values\n1-element Vector{Any}:\n Dict{String, ComplexF64}(\"0000000000\" => 0.7071067811865475 + 0.0im, \"1111111111\" => 0.7071067811865475 + 0.0im)","category":"page"},{"location":"sims/","page":"Simulators","title":"Simulators","text":"CurrentModule = BraketSimulator","category":"page"},{"location":"sims/#Simulators","page":"Simulators","title":"Simulators","text":"","category":"section"},{"location":"sims/","page":"Simulators","title":"Simulators","text":"BraketSimulators.jl provides two types of simulators: StateVectorSimulator for pure state simulation (without noise) and DensityMatrixSimulator for noisy simulation. Each type is parameterized by an element type (which should be a Julia Complex type, such as ComplexF64) and an array type (so that we can specialize for GPU arrays, for example).","category":"page"},{"location":"sims/","page":"Simulators","title":"Simulators","text":"Each simulator can be initialized with a qubit_count and shots value. You may query the properties of a simulator to learn what gate types, result types, and other operations it supports.","category":"page"},{"location":"sims/","page":"Simulators","title":"Simulators","text":"Modules = [BraketSimulator]","category":"page"},{"location":"sims/#BraketSimulator.DensityMatrixSimulator","page":"Simulators","title":"BraketSimulator.DensityMatrixSimulator","text":"DensityMatrixSimulator{T, S<:AbstractMatrix{T}} <: AbstractSimulator\n\nSimulator representing evolution of a density matrix of type S, with element type T. Density matrix simulators should be used to simulate circuits with noise.\n\n\n\n\n\n","category":"type"},{"location":"sims/#BraketSimulator.DensityMatrixSimulator-Union{Tuple{T}, Tuple{Type{T}, Int64, Int64}} where T<:Number","page":"Simulators","title":"BraketSimulator.DensityMatrixSimulator","text":"DensityMatrixSimulator([::T], qubit_count::Int, shots::Int) -> DensityMatrixSimulator{T, Matrix{T}}\n\nCreate a DensityMatrixSimulator with 2^qubit_count x 2^qubit_count elements and shots shots to be measured. The default element type is ComplexF64.\n\n\n\n\n\n","category":"method"},{"location":"sims/#BraketSimulator.StateVectorSimulator","page":"Simulators","title":"BraketSimulator.StateVectorSimulator","text":"StateVectorSimulator{T, S<:AbstractVector{T}} <: AbstractSimulator\n\nSimulator representing a pure state evolution of a statevector of type S, with element type T. State vector simulators should be used to simulate circuits without noise.\n\n\n\n\n\n","category":"type"},{"location":"sims/#BraketSimulator.StateVectorSimulator-Union{Tuple{T}, Tuple{Type{T}, Int64, Int64}} where T<:Number","page":"Simulators","title":"BraketSimulator.StateVectorSimulator","text":"StateVectorSimulator([::T], qubit_count::Int, shots::Int) -> StateVectorSimulator{T, Vector{T}}\n\nCreate a StateVectorSimulator with 2^qubit_count elements and shots shots to be measured. The default element type is ComplexF64.\n\n\n\n\n\n","category":"method"},{"location":"sims/#Braket.properties-Tuple{DensityMatrixSimulator}","page":"Simulators","title":"Braket.properties","text":"properties(svs::DensityMatrixSimulator) -> GateModelSimulatorDeviceCapabilities\n\nQuery the properties and capabilities of a DensityMatrixSimulator, including which gates and result types are supported and the minimum and maximum shot and qubit counts.\n\n\n\n\n\n","category":"method"},{"location":"sims/#Braket.properties-Tuple{StateVectorSimulator}","page":"Simulators","title":"Braket.properties","text":"properties(svs::StateVectorSimulator) -> GateModelSimulatorDeviceCapabilities\n\nQuery the properties and capabilities of a StateVectorSimulator, including which gates and result types are supported and the minimum and maximum shot and qubit counts.\n\n\n\n\n\n","category":"method"},{"location":"sims/#Braket.simulate-Tuple{BraketSimulator.AbstractSimulator, OpenQasmProgram}","page":"Simulators","title":"Braket.simulate","text":"simulate(simulator::AbstractSimulator, circuit_ir; shots::Int = 0, kwargs...) -> GateModelTaskResult\n\nSimulate the evolution of a statevector or density matrix using the passed in simulator. The instructions to apply (gates and noise channels) and measurements to make are encoded in circuit_ir. Supported IR formats are OpenQASMProgram (OpenQASM3) and Program (JAQCD). Returns a GateModelTaskResult containing the individual shot measurements (if shots > 0), final calculated results, circuit IR, and metadata about the task.\n\n\n\n\n\n","category":"method"},{"location":"sims/#BraketSimulator.evolve!-Union{Tuple{S}, Tuple{T}, Tuple{DensityMatrixSimulator{T, S}, Any}} where {T<:Complex, S<:AbstractMatrix{T}}","page":"Simulators","title":"BraketSimulator.evolve!","text":"evolve!(dms::DensityMatrixSimulator{T, S<:AbstractMatrix{T}}, operations::Vector{Instruction}) -> DensityMatrixSimulator{T, S}\n\nApply each operation of operations in-place to the density matrix contained in dms.\n\nEffectively, perform the operation:\n\nhatrho to hatA^dag hatrho hatA\n\nfor each operation hatA in operations.\n\n\n\n\n\n","category":"method"},{"location":"sims/#BraketSimulator.evolve!-Union{Tuple{S}, Tuple{T}, Tuple{StateVectorSimulator{T, S}, Any}} where {T<:Complex, S<:AbstractVector{T}}","page":"Simulators","title":"BraketSimulator.evolve!","text":"evolve!(svs::StateVectorSimulator{T, S<:AbstractVector{T}}, operations::Vector{Instruction}) -> StateVectorSimulator{T, S}\n\nApply each operation of operations in-place to the state vector contained in svs.\n\nEffectively, perform the operation:\n\nleft psi rightrangle to hatA left psi rightrangle\n\nfor each operation hatA in operations.\n\n\n\n\n\n","category":"method"},{"location":"sims/#BraketSimulator.expectation-Tuple{DensityMatrixSimulator, Observable, Vararg{Int64}}","page":"Simulators","title":"BraketSimulator.expectation","text":"expectation(dms::DensityMatrixSimulator, observable::Observables.Observable, targets::Int...) -> Float64\n\nCompute the exact (shots=0) expectation value of observable applied to targets given the evolved density matrix in dms. In other words, compute\n\nmathrmTrleft(hatOhatrhoright).\n\n\n\n\n\n","category":"method"},{"location":"sims/#BraketSimulator.expectation-Tuple{StateVectorSimulator, Observable, Vararg{Int64}}","page":"Simulators","title":"BraketSimulator.expectation","text":"expectation(svs::StateVectorSimulator, observable::Observables.Observable, targets::Int...) -> Float64\n\nCompute the exact (shots=0) expectation value of observable applied to targets given the evolved state vector in svs. In other words, compute\n\nlangle psi  hatO  psi rangle.\n\n\n\n\n\n","category":"method"},{"location":"sims/#BraketSimulator.probabilities-Tuple{StateVectorSimulator}","page":"Simulators","title":"BraketSimulator.probabilities","text":"probabilities(svs::StateVectorSimulator) -> Vector{Float64}\n\nCompute the observation probabilities of all amplitudes in the state vector in svs.\n\n\n\n\n\n","category":"method"}]
}
