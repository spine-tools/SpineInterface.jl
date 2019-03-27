using SpineInterface


function create_db(url::String; username::String="")
    db_api = SpineInterface.db_api
    db_api.create_new_spine_database(url, for_spine_model=false)
    db_map = db_api.DiffDatabaseMapping(url, username=username)
    db_api.import_object_classes(db_map, ["node", "unit", "connection"])
    db_api.import_objects(
        db_map,
        [
            [("node", "bus$i") for i in 1:30]...,
            [("unit", "gen$i") for i in 1:6]...,
            [("connection", "branch$i") for i in 1:41]...
        ]
    )
    db_api.import_relationship_classes(
        db_map,
        [
            ("unit__node", ["unit", "node"]),
            ("connection__from_node", ["connection", "node"]),
            ("connection__to_node", ["connection", "node"])
        ]
    )
    db_api.import_relationships(
        db_map,
        [
            ("unit__node", ["gen1", "bus1"]),
            ("unit__node", ["gen2", "bus2"]),
            ("unit__node", ["gen3", "bus5"]),
            ("unit__node", ["gen4", "bus8"]),
            ("unit__node", ["gen5", "bus11"]),
            ("unit__node", ["gen6", "bus13"]),
            ("connection__from_node", ["branch1",  "bus1"]),
            ("connection__from_node", ["branch2",  "bus1"]),
            ("connection__from_node", ["branch3",  "bus2"]),
            ("connection__from_node", ["branch4",  "bus3"]),
            ("connection__from_node", ["branch5",  "bus2"]),
            ("connection__from_node", ["branch6",  "bus2"]),
            ("connection__from_node", ["branch7",  "bus4"]),
            ("connection__from_node", ["branch8",  "bus5"]),
            ("connection__from_node", ["branch9",  "bus6"]),
            ("connection__from_node", ["branch10", "bus6"]),
            ("connection__from_node", ["branch11", "bus6"]),
            ("connection__from_node", ["branch12", "bus6"]),
            ("connection__from_node", ["branch13", "bus9"]),
            ("connection__from_node", ["branch14", "bus9"]),
            ("connection__from_node", ["branch15", "bus4"]),
            ("connection__from_node", ["branch16", "bus12"]),
            ("connection__from_node", ["branch17", "bus12"]),
            ("connection__from_node", ["branch18", "bus12"]),
            ("connection__from_node", ["branch19", "bus12"]),
            ("connection__from_node", ["branch20", "bus14"]),
            ("connection__from_node", ["branch21", "bus16"]),
            ("connection__from_node", ["branch22", "bus15"]),
            ("connection__from_node", ["branch23", "bus18"]),
            ("connection__from_node", ["branch24", "bus19"]),
            ("connection__from_node", ["branch25", "bus10"]),
            ("connection__from_node", ["branch26", "bus10"]),
            ("connection__from_node", ["branch27", "bus10"]),
            ("connection__from_node", ["branch28", "bus10"]),
            ("connection__from_node", ["branch29", "bus21"]),
            ("connection__from_node", ["branch30", "bus15"]),
            ("connection__from_node", ["branch31", "bus22"]),
            ("connection__from_node", ["branch32", "bus23"]),
            ("connection__from_node", ["branch33", "bus24"]),
            ("connection__from_node", ["branch34", "bus25"]),
            ("connection__from_node", ["branch35", "bus25"]),
            ("connection__from_node", ["branch36", "bus28"]),
            ("connection__from_node", ["branch37", "bus27"]),
            ("connection__from_node", ["branch38", "bus27"]),
            ("connection__from_node", ["branch39", "bus29"]),
            ("connection__from_node", ["branch40", "bus8"]),
            ("connection__from_node", ["branch41", "bus6"]),
            ("connection__to_node", ["branch1",  "bus2"]),
            ("connection__to_node", ["branch2",  "bus3"]),
            ("connection__to_node", ["branch3",  "bus4"]),
            ("connection__to_node", ["branch4",  "bus4"]),
            ("connection__to_node", ["branch5",  "bus5"]),
            ("connection__to_node", ["branch6",  "bus6"]),
            ("connection__to_node", ["branch7",  "bus6"]),
            ("connection__to_node", ["branch8",  "bus7"]),
            ("connection__to_node", ["branch9",  "bus7"]),
            ("connection__to_node", ["branch10", "bus8"]),
            ("connection__to_node", ["branch11", "bus9"]),
            ("connection__to_node", ["branch12", "bus10"]),
            ("connection__to_node", ["branch13", "bus11"]),
            ("connection__to_node", ["branch14", "bus10"]),
            ("connection__to_node", ["branch15", "bus12"]),
            ("connection__to_node", ["branch16", "bus13"]),
            ("connection__to_node", ["branch17", "bus14"]),
            ("connection__to_node", ["branch18", "bus15"]),
            ("connection__to_node", ["branch19", "bus16"]),
            ("connection__to_node", ["branch20", "bus15"]),
            ("connection__to_node", ["branch21", "bus17"]),
            ("connection__to_node", ["branch22", "bus18"]),
            ("connection__to_node", ["branch23", "bus19"]),
            ("connection__to_node", ["branch24", "bus20"]),
            ("connection__to_node", ["branch25", "bus20"]),
            ("connection__to_node", ["branch26", "bus17"]),
            ("connection__to_node", ["branch27", "bus21"]),
            ("connection__to_node", ["branch28", "bus22"]),
            ("connection__to_node", ["branch29", "bus22"]),
            ("connection__to_node", ["branch30", "bus23"]),
            ("connection__to_node", ["branch31", "bus24"]),
            ("connection__to_node", ["branch32", "bus24"]),
            ("connection__to_node", ["branch33", "bus25"]),
            ("connection__to_node", ["branch34", "bus26"]),
            ("connection__to_node", ["branch35", "bus27"]),
            ("connection__to_node", ["branch36", "bus27"]),
            ("connection__to_node", ["branch37", "bus29"]),
            ("connection__to_node", ["branch38", "bus30"]),
            ("connection__to_node", ["branch39", "bus30"]),
            ("connection__to_node", ["branch40", "bus28"]),
            ("connection__to_node", ["branch41", "bus28"]),
        ]
    )
    db_api.import_object_parameters(
        db_map,
        [
            ("node", "bus_type"),
            ("node", "real_power_demand", 0),
            ("node", "reactive_power_demand", 0),
            ("node", "min_voltage", 0.94),
            ("node", "max_voltage", 1.06),
            ("unit", "voltage_setpoint"),
            ("unit", "real_power_generation_setpoint", 0),
            ("unit", "max_real_power_output", 0),
            ("unit", "min_real_power_output", 0),
            ("unit", "max_reactive_power_output"),
            ("unit", "min_reactive_power_output"),
            ("unit", "fuel_cost", 0),
            ("connection", "resistance", 0),
            ("connection", "reactance"),
            ("connection", "tap_ratio", 1),
            ("connection", "shift_angle", 0),
            ("connection", "charging_susceptance", 0),
            ("connection", "long_term_rating")
        ]
    )
    db_api.import_object_parameter_values(
        db_map,
        [
            ("node", "bus1", "bus_type", "\"slack\""),
            ("node", "bus2", "real_power_demand", 21.7 / 100),
            ("node", "bus3", "real_power_demand", 2.4 / 100),
            ("node", "bus4", "real_power_demand", 7.6 / 100),
            ("node", "bus5", "real_power_demand", 94.2 / 100),
            ("node", "bus7", "real_power_demand", 22.8 / 100),
            ("node", "bus8", "real_power_demand", 30.0 / 100),
            ("node", "bus10", "real_power_demand", 5.8 / 100),
            ("node", "bus12", "real_power_demand", 11.2 / 100),
            ("node", "bus14", "real_power_demand", 6.2 / 100),
            ("node", "bus15", "real_power_demand", 8.2 / 100),
            ("node", "bus16", "real_power_demand", 3.5 / 100),
            ("node", "bus17", "real_power_demand", 9.0 / 100),
            ("node", "bus18", "real_power_demand", 3.2 / 100),
            ("node", "bus19", "real_power_demand", 9.5 / 100),
            ("node", "bus20", "real_power_demand", 2.2 / 100),
            ("node", "bus21", "real_power_demand", 17.5 / 100),
            ("node", "bus23", "real_power_demand", 3.2 / 100),
            ("node", "bus24", "real_power_demand", 8.7 / 100),
            ("node", "bus26", "real_power_demand", 3.5 / 100),
            ("node", "bus29", "real_power_demand", 2.4 / 100),
            ("node", "bus30", "real_power_demand", 10.6 / 100),
            ("node", "bus2", "reactive_power_demand", 12.7 / 100),
            ("node", "bus3", "reactive_power_demand", 1.2 / 100),
            ("node", "bus4", "reactive_power_demand", 1.6 / 100),
            ("node", "bus5", "reactive_power_demand", 19.0 / 100),
            ("node", "bus7", "reactive_power_demand", 10.9 / 100),
            ("node", "bus8", "reactive_power_demand", 30.0 / 100),
            ("node", "bus10", "reactive_power_demand", 2.0 / 100),
            ("node", "bus12", "reactive_power_demand", 7.5 / 100),
            ("node", "bus14", "reactive_power_demand", 1.6 / 100),
            ("node", "bus15", "reactive_power_demand", 2.5 / 100),
            ("node", "bus16", "reactive_power_demand", 1.8 / 100),
            ("node", "bus17", "reactive_power_demand", 5.8 / 100),
            ("node", "bus18", "reactive_power_demand", 0.9 / 100),
            ("node", "bus19", "reactive_power_demand", 3.4 / 100),
            ("node", "bus20", "reactive_power_demand", 0.7 / 100),
            ("node", "bus21", "reactive_power_demand", 11.2 / 100),
            ("node", "bus23", "reactive_power_demand", 1.6 / 100),
            ("node", "bus24", "reactive_power_demand", 6.7 / 100),
            ("node", "bus26", "reactive_power_demand", 2.3 / 100),
            ("node", "bus29", "reactive_power_demand", 0.9 / 100),
            ("node", "bus30", "reactive_power_demand", 1.9 / 100),
            ("unit", "gen1", "real_power_generation_setpoint", 218.839 / 100),
            ("unit", "gen2", "real_power_generation_setpoint", 80.05 / 100),
            ("unit", "gen1", "voltage_setpoint", 1.06),
            ("unit", "gen2", "voltage_setpoint", 1.03591),
            ("unit", "gen3", "voltage_setpoint", 0.99748),
            ("unit", "gen4", "voltage_setpoint", 1.00241),
            ("unit", "gen5", "voltage_setpoint", 1.06),
            ("unit", "gen6", "voltage_setpoint", 1.06),
            ("unit", "gen1", "fuel_cost", 0.521378),
            ("unit", "gen2", "fuel_cost", 1.135166),
            ("unit", "gen1", "max_real_power_output", 784 / 100),
            ("unit", "gen2", "max_real_power_output", 100 / 100),
            ("unit", "gen1", "max_reactive_power_output", 10 / 100),
            ("unit", "gen2", "max_reactive_power_output", 50 / 100),
            ("unit", "gen3", "max_reactive_power_output", 40 / 100),
            ("unit", "gen4", "max_reactive_power_output", 40 / 100),
            ("unit", "gen5", "max_reactive_power_output", 24 / 100),
            ("unit", "gen6", "max_reactive_power_output", 24 / 100),
            ("unit", "gen1", "min_reactive_power_output", 0),
            ("unit", "gen2", "min_reactive_power_output", -40 / 100),
            ("unit", "gen3", "min_reactive_power_output", -40 / 100),
            ("unit", "gen4", "min_reactive_power_output", -10 / 100),
            ("unit", "gen5", "min_reactive_power_output", -6 / 100),
            ("unit", "gen6", "min_reactive_power_output", -6 / 100),
            ("connection", "branch1", "resistance", 0.0192),
            ("connection", "branch2", "resistance", 0.0452),
            ("connection", "branch3", "resistance", 0.057),
            ("connection", "branch4", "resistance", 0.0132),
            ("connection", "branch5", "resistance", 0.0472),
            ("connection", "branch6", "resistance", 0.0581),
            ("connection", "branch7", "resistance", 0.0119),
            ("connection", "branch8", "resistance", 0.046),
            ("connection", "branch9", "resistance", 0.0267),
            ("connection", "branch10", "resistance", 0.012),
            ("connection", "branch17", "resistance", 0.1231),
            ("connection", "branch18", "resistance", 0.0662),
            ("connection", "branch19", "resistance", 0.0945),
            ("connection", "branch20", "resistance", 0.221),
            ("connection", "branch21", "resistance", 0.0524),
            ("connection", "branch22", "resistance", 0.1073),
            ("connection", "branch23", "resistance", 0.0639),
            ("connection", "branch24", "resistance", 0.034),
            ("connection", "branch25", "resistance", 0.0936),
            ("connection", "branch26", "resistance", 0.0324),
            ("connection", "branch27", "resistance", 0.0348),
            ("connection", "branch28", "resistance", 0.0727),
            ("connection", "branch29", "resistance", 0.0116),
            ("connection", "branch30", "resistance", 0.1),
            ("connection", "branch31", "resistance", 0.115),
            ("connection", "branch32", "resistance", 0.132),
            ("connection", "branch33", "resistance", 0.1885),
            ("connection", "branch34", "resistance", 0.2544),
            ("connection", "branch35", "resistance", 0.1093),
            ("connection", "branch36", "resistance", 0.0),
            ("connection", "branch37", "resistance", 0.2198),
            ("connection", "branch38", "resistance", 0.3202),
            ("connection", "branch39", "resistance", 0.2399),
            ("connection", "branch40", "resistance", 0.0636),
            ("connection", "branch41", "resistance", 0.0169),
            ("connection", "branch1", "reactance", 0.0575),
            ("connection", "branch2", "reactance", 0.1652),
            ("connection", "branch3", "reactance", 0.1737),
            ("connection", "branch4", "reactance", 0.0379),
            ("connection", "branch5", "reactance", 0.1983),
            ("connection", "branch6", "reactance", 0.1763),
            ("connection", "branch7", "reactance", 0.0414),
            ("connection", "branch8", "reactance", 0.116),
            ("connection", "branch9", "reactance", 0.082),
            ("connection", "branch10", "reactance", 0.042),
            ("connection", "branch11", "reactance", 0.208),
            ("connection", "branch12", "reactance", 0.556),
            ("connection", "branch13", "reactance", 0.208),
            ("connection", "branch14", "reactance", 0.11),
            ("connection", "branch15", "reactance", 0.256),
            ("connection", "branch16", "reactance", 0.14),
            ("connection", "branch17", "reactance", 0.2559),
            ("connection", "branch18", "reactance", 0.1304),
            ("connection", "branch19", "reactance", 0.1987),
            ("connection", "branch20", "reactance", 0.1997),
            ("connection", "branch21", "reactance", 0.1923),
            ("connection", "branch22", "reactance", 0.2185),
            ("connection", "branch23", "reactance", 0.1292),
            ("connection", "branch24", "reactance", 0.068),
            ("connection", "branch25", "reactance", 0.209),
            ("connection", "branch26", "reactance", 0.0845),
            ("connection", "branch27", "reactance", 0.0749),
            ("connection", "branch28", "reactance", 0.1499),
            ("connection", "branch29", "reactance", 0.0236),
            ("connection", "branch30", "reactance", 0.202),
            ("connection", "branch31", "reactance", 0.179),
            ("connection", "branch32", "reactance", 0.27),
            ("connection", "branch33", "reactance", 0.3292),
            ("connection", "branch34", "reactance", 0.38),
            ("connection", "branch35", "reactance", 0.2087),
            ("connection", "branch36", "reactance", 0.396),
            ("connection", "branch37", "reactance", 0.4153),
            ("connection", "branch38", "reactance", 0.6027),
            ("connection", "branch39", "reactance", 0.4533),
            ("connection", "branch40", "reactance", 0.2),
            ("connection", "branch41", "reactance", 0.0599),
            ("connection", "branch1", "charging_susceptance", 0.0528),
            ("connection", "branch2", "charging_susceptance", 0.0408),
            ("connection", "branch3", "charging_susceptance", 0.0368),
            ("connection", "branch4", "charging_susceptance", 0.0084),
            ("connection", "branch5", "charging_susceptance", 0.0418),
            ("connection", "branch6", "charging_susceptance", 0.0374),
            ("connection", "branch7", "charging_susceptance", 0.009),
            ("connection", "branch8", "charging_susceptance", 0.0204),
            ("connection", "branch9", "charging_susceptance", 0.017),
            ("connection", "branch10", "charging_susceptance", 0.009),
            ("connection", "branch40", "charging_susceptance", 0.0428),
            ("connection", "branch41", "charging_susceptance", 0.013),
            ("connection", "branch1", "long_term_rating", 138 / 100),
            ("connection", "branch2", "long_term_rating", 152 / 100),
            ("connection", "branch3", "long_term_rating", 139 / 100),
            ("connection", "branch4", "long_term_rating", 135 / 100),
            ("connection", "branch5", "long_term_rating", 144 / 100),
            ("connection", "branch6", "long_term_rating", 139 / 100),
            ("connection", "branch7", "long_term_rating", 148 / 100),
            ("connection", "branch8", "long_term_rating", 127 / 100),
            ("connection", "branch9", "long_term_rating", 140 / 100),
            ("connection", "branch10", "long_term_rating", 148 / 100),
            ("connection", "branch11", "long_term_rating", 142 / 100),
            ("connection", "branch12", "long_term_rating", 53 / 100),
            ("connection", "branch13", "long_term_rating", 142 / 100),
            ("connection", "branch14", "long_term_rating", 267 / 100),
            ("connection", "branch15", "long_term_rating", 115 / 100),
            ("connection", "branch16", "long_term_rating", 210 / 100),
            ("connection", "branch17", "long_term_rating", 29 / 100),
            ("connection", "branch18", "long_term_rating", 29 / 100),
            ("connection", "branch19", "long_term_rating", 30 / 100),
            ("connection", "branch20", "long_term_rating", 20 / 100),
            ("connection", "branch21", "long_term_rating", 38 / 100),
            ("connection", "branch22", "long_term_rating", 29 / 100),
            ("connection", "branch23", "long_term_rating", 29 / 100),
            ("connection", "branch24", "long_term_rating", 29 / 100),
            ("connection", "branch25", "long_term_rating", 30 / 100),
            ("connection", "branch26", "long_term_rating", 33 / 100),
            ("connection", "branch27", "long_term_rating", 30 / 100),
            ("connection", "branch28", "long_term_rating", 29 / 100),
            ("connection", "branch29", "long_term_rating", 29 / 100),
            ("connection", "branch30", "long_term_rating", 29 / 100),
            ("connection", "branch31", "long_term_rating", 26 / 100),
            ("connection", "branch32", "long_term_rating", 29 / 100),
            ("connection", "branch33", "long_term_rating", 27 / 100),
            ("connection", "branch34", "long_term_rating", 25 / 100),
            ("connection", "branch35", "long_term_rating", 28 / 100),
            ("connection", "branch36", "long_term_rating", 75 / 100),
            ("connection", "branch37", "long_term_rating", 28 / 100),
            ("connection", "branch38", "long_term_rating", 28 / 100),
            ("connection", "branch39", "long_term_rating", 28 / 100),
            ("connection", "branch40", "long_term_rating", 140 / 100),
            ("connection", "branch41", "long_term_rating", 149 / 100),
            ("connection", "branch11", "tap_ratio", 0.978),
            ("connection", "branch12", "tap_ratio", 0.969),
            ("connection", "branch15", "tap_ratio", 0.932),
            ("connection", "branch36", "tap_ratio", 0.968)
        ]
    )
    try
        db_map.commit_session("First commit.")
    catch e
        db_map.rollback_session()
    finally
        db_map.close()
    end
end


file_path = "case30_m.sqlite"
url = "sqlite:///" * file_path
isfile(file_path) && rm(file_path)
create_db(url; username="manuelma")
