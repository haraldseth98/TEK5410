* Set of hours in a year
set h / h1*h8760 /; 

* Set of different energy generation technologies
set technology /
    wind
    pv
    hydro
    other
    gas
    coal
    biomass
/;

* Hourly demand for Germany in 2022
parameter demand(h) /  
$include Germany_demand_TurbulentTimes.tsv
/;

* Hourly generated capacity factors for different technologies
parameter capacity_factors(h, technology) / 
$include Germany_CF_TT.tsv
/;


* Annuitised costs for different technologies in EUR / MW
* calculated using investment costs from https://www.eia.gov/outlooks/aeo/assumptions/pdf/table_8.2.pdf

*                   Harmony Horizon     Turbulent Times     Base Scenario
* Wind              315 700 [EUR/MW]    416 600 [EUR/MW]    240 770 [EUR/MW]
* PV                95 970 [EUR/MW]     132 270 [EUR/MW]    67 750 [EUR/MW]
* Hydro             297 900 [EUR/MW]    402 140 [EUR/MW]    217 700 [EUR/MW]
* Other           550 000 [EUR/MW]    783 290 [EUR/MW]    357 990 [EUR/MW]
* Gas               115 160 [EUR/MW]    158 730 [EUR/MW]    81 300 [EUR/MW]
* Coal              371 400 [EUR/MW]    523 500 [EUR/MW]    249 300 [EUR/MW]
* Biomass           383 870 [EUR/MW]    529 100 [EUR/MW]    271 000 [EUR/MW]

parameter annuitised_costs(technology) / 
    wind 416600
    pv 132270
    hydro 402140
    other 10000000
    gas 158730
    coal 523500
    biomass 529100
/;

* Variable costs for different technologies in EUR / MWh
* from https://atb.nrel.gov/electricity/2022/index
parameter var_costs(technology) / 
    wind 0.5
    pv 0.035
    hydro 0.3
    other 10000
    gas 3.5
    coal 13
    biomass 5.0
/;

* Set maximum installed capacity for each technology, reflecting scenario [MW]
parameter max_installed_cap(technology) /
    wind 200000
    pv 200000
    hydro 4900
    other INF
    gas INF
    coal INF
    biomass INF
/;

* Target reduction percentage in emissions
parameter target_emission_reduction / 0.10 /;

* Reference Emission Level (1990)
parameter target_emissions / 1250000000 / ;

* Emission intensity for different technologies in tCO2 / MWh
* from: https://app.electricitymaps.com/zone/DE
parameter emission_intensity(technology) /
    wind 0.013
    pv 0.035
    hydro 0.011
    other 0
    gas 0.593
    coal 1.152
    biomass 0.230
/;

* Installed capacity for each technology
positive variables
    var_installed_cap(technology);


free variables
* Total system cost
    var_system_cost
* Total emissions
    var_emissions; 

* Generated energy for each hour and technology
positive variables
    var_g(h, technology) "Generated energy for each hour and technology"; 

equations
* Objective function
    eq_objective
* Demand balance equation
    eq_demand_balance
* Energy generation conversion equation
    eq_gen_convert
* Total emissions equation
    eq_emissions
* Emissions control equation
    eq_emissions_control
* Constraint for renewable energy limit
    eq_renewable_limit "Constraint for renewable limit"
* Upper installed capacity equation  
    eq_max_installed_cap(technology);

* Total system cost objective function
eq_objective.. var_system_cost =E= sum((technology), annuitised_costs(technology) * var_installed_cap(technology))
                                    + sum((h, technology), var_g(h, technology) * var_costs(technology));
    
* Demand balance constraint                    
eq_demand_balance(h).. sum((technology), var_g(h, technology)) =G= demand(h);

* Energy generation conversion constraint
eq_gen_convert(h, technology).. var_g(h, technology) =L= var_installed_cap(technology) * capacity_factors(h, technology);

* Total emissions equation
eq_emissions.. var_emissions =E= sum((h, technology), var_g(h, technology) * emission_intensity(technology));

* Emissions control constraint
eq_emissions_control.. var_emissions =L= target_emissions * (1 - target_emission_reduction);

* Constraint for renewable energy limit
eq_renewable_limit(h).. sum(technology$(ord(technology) <= 4), var_g(h, technology)) =G= 0.15 * sum(technology, var_g(h, technology)); 

* Constraint so that installed capacity does not exceed the upper threshold value
eq_max_installed_cap(technology).. var_installed_cap(technology) =L= max_installed_cap(technology);



* Defining the model
model optimal_generation /  
    all /;

* Solving the model
solve optimal_generation minimizing var_system_cost using lp;  

* Save results to GDX file
execute_unload 'TurbulentTimes.gdx' var_g, var_installed_cap, var_system_cost;

* Export results to SQLite database
execute 'gdx2sqlite -i TurbulentTimes.gdx -o resultsTurbulentTimes.db -fast'; 



