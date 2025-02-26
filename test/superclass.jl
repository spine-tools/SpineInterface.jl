#=
    superclass.jl

Temporary(?) file for WIP superclass unit tests.
=#

function _test_superclass() # Test based on an imagined SpineOpt use-case.
    @testset "superclass" begin
        # Note that this test needs to use the v0.8 datastructures to handle compound entity classes and superclasses.
        ent_clss = [
            ["node", []],
            ["unit", []],
            ["unit__node", ["unit", "node"]],
            ["node__unit", ["node", "unit"]],
            ["unit_flow", []],
            ["unit_flow__unit_flow", ["unit_flow", "unit_flow"]]
        ]
        supcls_subclss = [
            ["unit_flow", "node__unit"],
            ["unit_flow", "unit__node"]
        ]
        ents = [
            ["node", "n1"],
            ["node", "n2"],
            ["unit", "u1"],
            ["node__unit", ["n1", "u1"]],
            ["node__unit", ["n2", "u1"]],
            ["unit__node", ["u1", "n2"]],
            ["unit__node", ["u1", "n1"]],
            ["unit_flow", "n1u1n2"], # Test "object" in unit_flow.
            ["unit_flow__unit_flow", ["n1__u1", "u1__n2"]], # Entity names not shown in old import data structures, IMPORT NOT WORKING!
            ["unit_flow__unit_flow", ["n2__u1", "u1__n1"]], # Entity names not shown in old import data structures, IMPORT NOT WORKING!
        ]
        param_defs = [
            ["unit_flow", "unit_flow_cost"],
            ["unit_flow__unit_flow", "unit_flow_ratio"]
        ]
        param_vals = [
            ["unit_flow", "n1__u1", "unit_flow_cost", 1.0], # Entity names not shown in old import data structures
            ["unit_flow", "u1__n2", "unit_flow_cost", 2.0], # Entity names not shown in old import data structures
            ["unit_flow", "n1u1n2", "unit_flow_cost", 3.0], # Test "object" parameter here.
            ["unit_flow__unit_flow", ["n1__u1", "u1__n2"], "unit_flow_ratio", 1.0], # Entity names not shown in old import data structures
            ["unit_flow__unit_flow", ["n2__u1", "u1__n1"], "unit_flow_ratio", 2.0], # Entity names not shown in old import data structures
        ]
        import_test_data(
            db_url;
            entity_classes=ent_clss,
            superclass_subclasses=supcls_subclss,
            entities=ents,
            parameter_definitions=param_defs,
            parameter_values=param_vals
        )
        using_spinedb(db_url)
        # TODO: Test superclass functionality once DB API can handle these.
    end
end