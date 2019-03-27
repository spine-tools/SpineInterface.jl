using Revise
using SpineInterface
using JuMP
using Ipopt


function variable_voltage_and_phase(m::Model)
    @butcher Dict{Symbol, JuMP.VariableRef}(
        n => @variable(
            m, base_name="voltage[$n]", lower_bound=min_voltage(node=n), upper_bound=max_voltage(node=n)
        ) for n in node()
    ),
    @butcher Dict{Symbol, JuMP.VariableRef}(
        n => @variable(
            m, base_name="phase[$n]"
        ) for n in node()
    )
end

function variable_power_generation(m::Model)
    @butcher Dict{Symbol, JuMP.VariableRef}(
        u => @variable(
            m, base_name="real_power_generation[$u]",
            lower_bound=min_real_power_output(unit=u), upper_bound=max_real_power_output(unit=u)
        ) for u in unit()
    ),
    @butcher Dict{Symbol, JuMP.VariableRef}(
        u => @variable(
            m, base_name="reactive_power_generation[$u]",
            lower_bound=min_reactive_power_output(unit=u), upper_bound=max_reactive_power_output(unit=u)
        ) for u in unit()
    )
end

function variable_power_flow_to_node(m::Model)
    @butcher Dict{Tuple, JuMP.VariableRef}(
        (c, n) => @variable(
            m, base_name="real_power_flow_to_node[$c, $n]",
            lower_bound=-long_term_rating(connection=c), upper_bound=long_term_rating(connection=c)
        ) for (c, n) in connection__to_node()
    ),
    @butcher Dict{Tuple, JuMP.VariableRef}(
        (c, n) => @variable(
            m, base_name="reactive_power_flow_to_node[$c, $n]",
            lower_bound=-long_term_rating(connection=c), upper_bound=long_term_rating(connection=c)
        ) for (c, n) in connection__to_node()
    )
end

function variable_power_flow_from_node(m::Model)
    @butcher Dict{Tuple, JuMP.VariableRef}(
        (c, n) => @variable(
            m, base_name="real_power_flow_from_node[$c, $n]",
            lower_bound=-long_term_rating(connection=c), upper_bound=long_term_rating(connection=c)
        ) for (c, n) in connection__from_node()
    ),
    @butcher Dict{Tuple, JuMP.VariableRef}(
        (c, n) => @variable(
            m, base_name="reactive_power_flow_from_node[$c, $n]",
            lower_bound=-long_term_rating(connection=c), upper_bound=long_term_rating(connection=c)
        ) for (c, n) in connection__from_node()
    )
end

function objective_min_fuel_cost(m::Model, real_power_generation)
    @objective(
        m,
        Min,
        sum(fuel_cost(unit=u) * real_power_generation[u] for u in unit())
    )
end

function contraint_generator_setpoint(m::Model, voltage, phase, real_power_generation, reactive_power_generation)
    for (u, n) in unit__node()
        # Voltage setpoint
        fix(voltage[n], voltage_setpoint(unit=u); force=true)
        # Generation setpoint
        if bus_type(node=n) == :slack
            fix(phase[n], 0; force=true)
            delete_upper_bound(real_power_generation[u])
            delete_lower_bound(reactive_power_generation[u])
            delete_upper_bound(reactive_power_generation[u])
        else
            fix(real_power_generation[u], real_power_generation_setpoint(unit=u); force=true)
        end
    end
end

function constraint_nodal_balance(
        m::Model, real_power_generation, real_power_flow,
        real_power_flow_from_node, reactive_power_flow_from_node,
        real_power_flow_to_node, reactive_power_flow_to_node)
    @constraint(
        m,
        real_power_balance[n in node()],
        + sum(real_power_generation[u] for u in unit__node(node=n))
        - real_power_demand(node=n)
        + sum(real_power_flow_to_node[c, n] for c in connection__to_node(node=n))
        - sum(real_power_flow_from_node[c, n] for c in connection__from_node(node=n))
        ==
        0
    )
    @constraint(
        m,
        reactive_power_balance[n in node()],
        + sum(reactive_power_generation[u] for u in unit__node(node=n))
        - reactive_power_demand(node=n)
        + sum(reactive_power_flow_to_node[c, n] for c in connection__to_node(node=n))
        - sum(reactive_power_flow_from_node[c, n] for c in connection__from_node(node=n))
        ==
        0
    )
end

function constraint_power_flow(
        m::Model, voltage, phase,
        real_power_flow_from_node, reactive_power_flow_from_node,
        real_power_flow_to_node, reactive_power_flow_to_node)
    # Build dictionaries to save work, and avoid calling kwargs functions in NLConstraint
    y = Dict(c => 1 / (resistance(connection=c) + im * reactance(connection=c)) for c in connection())
    g = Dict(c => real(y[c]) for c in connection())
    b = Dict(c => imag(y[c]) for c in connection())
    charging_b = Dict(c => charging_susceptance(connection=c) for c in connection())
    tap = Dict(c => tap_ratio(connection=c) for c in connection())
    shift = Dict(c => shift_angle(connection=c) for c in connection())
    # Real power flow from bus
    @NLconstraint(
        m,
        [
            (c, from) in connection__from_node(),
            to = connection__to_node(connection=c)
        ],
        + real_power_flow_from_node[c, from]
        ==
        + g[c] * (voltage[from] / tap[c])^2
        - g[c] * (voltage[from] / tap[c]) * voltage[to] * cos(phase[from] - phase[to] - shift[c])
        - b[c] * (voltage[from] / tap[c]) * voltage[to] * sin(phase[from] - phase[to] - shift[c])
    )
    # Reactive power flow from bus
    @NLconstraint(
        m,
        [
            (c, from) in connection__from_node(),
            to = connection__to_node(connection=c)
        ],
        + reactive_power_flow_from_node[c, from]
        ==
        - (b[c] + charging_b[c] / 2) * (voltage[from] / tap[c])^2
        + b[c] * (voltage[from] / tap[c]) * voltage[to] * cos(phase[from] - phase[to] - shift[c])
        - g[c] * (voltage[from] / tap[c]) * voltage[to] * sin(phase[from] - phase[to] - shift[c])
    )
    # Real power flow to bus
    @NLconstraint(
        m,
        [
            (c, to) in connection__to_node(),
            from = connection__from_node(connection=c),
        ],
        - real_power_flow_to_node[c, to]
        ==
        + g[c] * voltage[to]^2
        - g[c] * voltage[to] * (voltage[from] / tap[c]) * cos(phase[to] - phase[from] + shift[c])
        - b[c] * voltage[to] * (voltage[from] / tap[c]) * sin(phase[to] - phase[from] + shift[c])
    )
    # Reactive power flow to bus
    @NLconstraint(
        m,
        [
            (c, to) in connection__to_node(),
            from = connection__from_node(connection=c),
        ],
        - reactive_power_flow_to_node[c, to]
        ==
        - (b[c] + charging_b[c] / 2) * voltage[to]^2
        + b[c] * voltage[to] * (voltage[from] / tap[c]) * cos(phase[to] - phase[from] + shift[c])
        - g[c] * voltage[to] * (voltage[from] / tap[c]) * sin(phase[to] - phase[from] + shift[c])
    )
end


# Interface database
url = "sqlite:///case30_m.sqlite"
spinal_check(url)
# Build model
m = Model(with_optimizer(Ipopt.Optimizer))
# Generate variables
real_power_generation, reactive_power_generation = variable_power_generation(m)
voltage, phase = variable_voltage_and_phase(m)
real_power_flow_from_node, reactive_power_flow_from_node = variable_power_flow_from_node(m)
real_power_flow_to_node, reactive_power_flow_to_node = variable_power_flow_to_node(m)
# Generate constraints
constraint_nodal_balance(
    m, real_power_generation, reactive_power_generation,
    real_power_flow_from_node, reactive_power_flow_from_node,
    real_power_flow_to_node, reactive_power_flow_to_node)
constraint_power_flow(
    m, voltage, phase,
    real_power_flow_from_node, reactive_power_flow_from_node,
    real_power_flow_to_node, reactive_power_flow_to_node)
# contraint_generator_setpoint(m, voltage, phase, real_power_generation, reactive_power_generation)
objective_min_fuel_cost(m, real_power_generation)
println(m)
optimize!(m)
@show status = termination_status(m)
result_url = "sqlite:///case30_m_result.sqlite"
write_results!(
    result_url, url;
    upgrade=true,
    voltage=Dict(k => JuMP.value(v) for (k, v) in voltage),
    phase=Dict(k => JuMP.value(v) for (k, v) in phase),
    real_power_generation=Dict(k => JuMP.value(v) for (k, v) in real_power_generation),
    reactive_power_generation=Dict(k => JuMP.value(v) for (k, v) in reactive_power_generation),
    real_power_flow_from_node=Dict(k => JuMP.value(v) for (k, v) in real_power_flow_from_node),
    reactive_power_flow_from_node=Dict(k => JuMP.value(v) for (k, v) in reactive_power_flow_from_node),
    real_power_flow_to_node=Dict(k => JuMP.value(v) for (k, v) in real_power_flow_to_node),
    reactive_power_flow_to_node=Dict(k => JuMP.value(v) for (k, v) in reactive_power_flow_to_node))
