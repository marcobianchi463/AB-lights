/**
* Name: ToyModel
* Based on the internal skeleton template. 
* Author: marco
* Tags: 
*/

model ToyModel

global {
	/** Insert the global definitions, variables and actions here */
	file shape_file_buildings <- file("../includes/qgis/building.shp") ; 
	file shape_file_roads <- file("../includes/qgis/split_road.shp") ;
	file shape_file_nodes <- file("../includes/qgis/junction.shp") ;
	geometry shape <- envelope(shape_file_roads) ;
	
	float step <- 1 #second ;
	int nb_vehicles <- 80 ;
	float respawn_prob <- 1.0 ;
	int dimension <- 1 ;
	int v_maxspeed <- 150 ;
	graph the_graph ;
	init {
		create building from: shape_file_buildings ;
		create road from: shape_file_roads with:[
			num_lanes::max(2, int(read("lanes"))),
			maxspeed::max(30.0, (read("maxspeed_t")="urban:it")? 30.0 : 50.0),
			oneway::string(read("oneway"))]{
				switch oneway {
					match "no" {
						create road {
							num_lanes <- myself.num_lanes ;
		                    shape <- polyline(reverse(myself.shape.points)) ;
		                    maxspeed <- myself.maxspeed ;
		                    linked_road <- myself ;
		                    myself.linked_road <- self ;
						}					
					}
				}
			}
		create road_node from: shape_file_nodes ;
		
		the_graph <- as_driving_graph (road, road_node) ;
		
		create vehicle number: nb_vehicles {
			location <- one_of(road_node).location ;
			max_speed <- v_maxspeed #km / #h;
			vehicle_length <- 3.0 #m ;
		}
		
		// INIZIALIZZAZIONE SEMAFORI
		// loop sui nodi della rete. Se le strade sono più di due il nodo diventa un semaforo
		int rndnum <- rnd(100) ;
		loop i over: road_node {
			write i.index ;
			write i.name ;
			
			//conto quante strade a doppio senso ci sono nel nodo
			loop j over: i.roads_in {
				// a quanto pare loopare su una lista di agenti strada non è abbastanza
				// per far capire che j è una strada 
				if (road(j).linked_road != nil) {
					i.linked_count <- i.linked_count + 1 ;
				}
			}
			//	controllo se il nodo è un incrocio: se ha più di 2 strade in ingresso è sempre un incrocio
			//	se ha 2 strade in ingresso a doppio senso e nessun'altra strada in uscita non è un incrocio
			if (length(i.roads_in) > 2 or length(i.roads_in) = 2 and !(i.linked_count = length(i.roads_out))) {
				i.is_traffic_light <- true ;
				i.timer <- rnd(i.green_time) ;	/* inizializzo randomicamente la fase del semaforo */
				i.timer <- rndnum ;		// con questo tutti i semafori hanno la stessa fase
				//inizializzo lo stato iniziale del semaforo
				loop j from: 0 to: length(i.roads_in) - 1 step: 2 {
					add i.roads_in at j to: i.roads_in_even ;
				}
				loop j from: 1 to: length(i.roads_in) - 1 step: 2 {
					add i.roads_in at j to: i.roads_in_odd ;
				}
				add i.roads_in_even to: i.stop ;
			}
			write (i.is_traffic_light) ? "is traffic light" : "is not traffic light";
		}
	}
}

// Veicoli definiti con skill advanced_driving
species vehicle skills: [advanced_driving] {
	rgb color <- rnd_color(255) ;
	/*init{
		vehicle_length <- 3.8 #m ;
		max_speed <- 150 #km / #h ;
	}*/
	
	reflex time_to_go when: final_target = nil {
		// se il veicolo si blocca all'arrivo ha una probabilità di cambiare posizione
		// questo serve nei casi in cui il nodo di arrivo ha solo strade in ingresso
		// per mappe grandi è raro che succeda, ma non in mappe piccole 
		if (flip(respawn_prob)){
			location <- one_of(road_node) ;
		}
		current_path <- compute_path (graph: the_graph, target: one_of(road_node)) ;
	}
	reflex move when: final_target != nil {
		do drive ;
	}
	aspect default {
	draw circle(dimension) color: color ;
	}
	
	//aspetto rettangolare con freccia direzionale
	aspect rect {
		if (current_road != nil) {
			draw rectangle(vehicle_length*dimension, dimension #m) at: location color: color rotate: heading border: #black;
			draw triangle(1 #m) at: location color: #white rotate: heading + 90 ;
		}
	}
}

species road skills: [road_skill] {
	rgb color <- #blue ;
	string oneway ;
	aspect base {
		draw shape color: color ;
	}
}

// specie road_node con intersection_skill
species road_node skills: [intersection_skill] {
	bool is_traffic_light <- false ;
	int timer ;
	int linked_count <- 0 ;	//	numero di strade a doppio senso di marcia, necessario per determinare se un nodo è un incrocio
	
	int green_time <- 60 #s ;
	int red_time <- 60 #s ;
	bool road_even_ok <- true ;	//	quando true è verde per le strade con indice pari
	rgb color <- #green ;
	list roads_in_even <- [] ;	//	sono le strade in ingresso con indice pari
	list roads_in_odd <- [] ;	//	sono le strade in ingrsso con indice dispari
	
	reflex classic_update_state when: is_traffic_light {
		timer <- timer + 1 ;
		if (!road_even_ok and timer >= green_time) {
			timer <- 0 ;
			color <- #red ;
			do switch_state ;			
		} else if (timer >= red_time) {
			timer <- 0 ;
			color <- #green ;
			do switch_state ;
		}
	}
	
	int switch_state {
		stop[] <- road_even_ok? roads_in_even : roads_in_odd ;	//	fermo le strade pari se finora avevano il verde
		road_even_ok <- !road_even_ok ;							//	altrimenti fermo le dispari, poi aggiorno road_even_ok
		return 0 ;
	}
	
	aspect default {
		if (is_traffic_light) {
			//	disegno un triangolo del colore del semaforo orientato verso la prima strada in ingresso
			draw triangle(7) rotate: towards(location,roads_in[0].location) + 180 color: color ;
		} else {
			draw circle(1) color: #black ;
		}
	}
}

species building {
	rgb color <- #gray ;
	aspect default {
		draw shape color:color ;
	}
}

experiment ToyModel type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_nodes category: "GIS" ;
	parameter "Probability of respawn:" var: respawn_prob category: "BOH" ;
	parameter "Vehicle dimension:" var: dimension ;
	parameter "Number of vehicles:" var: nb_vehicles ;
	parameter "Maximum speed:" var: v_maxspeed ;
		
	output {
		display city_display type:2d {
			species building aspect: default ;
			species road aspect: base ;
			species vehicle aspect: rect ;
			species road_node aspect:default ;
		}
	}
}