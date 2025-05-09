/**
* Name: TrafficLightModel
* Based on the internal skeleton template. 
* Author: marco
* Tags: 
*/

model TrafficLightModel

global {
	/** Insert the global definitions, variables and actions here */
	file shape_file_buildings <- file("../includes/qgis/building.shp") ; 
	file shape_file_roads <- file("../includes/qgis/split_road_clean.shp") ;
	file shape_file_nodes <- file("../includes/qgis/junction_clean.shp") ;
	geometry shape <- envelope(shape_file_roads) ;
	
	float step <- 1.0 #second ;
	int nb_vehicles <- 0 ;
	int nb_bus_lines <- 1 ;
	int nb_bus_min <- 2 ;
	list<road_node> bus_destinations <- [] ;
	list<road_node> bus_sources <- [] ;
	float respawn_prob <- 1.0 ;
	int dimension <- 1 ;
	int v_maxspeed <- 150 ;
	bool intelligent_g <- false ;
	bool stupid_g <- true ;
	float t_ang_toll <- 10.0 ;
	// int min_timer <- 15 ;
	int n_trips <- 0 ;
	list<int> trips <- [] ;
	float proba_rerouting <- 0.0 ;
	float car_weight <- 100.0 ;
	
	bool left_lane_choice <- false ;

	// variabili per la gestione dei semafori
	int min_timer <- int( 30 / step ) ;
	int max_timer <- int( 150 / step ) ;

	graph the_graph ;
	init {
		loop times: 10 {
			add 0 to: trips ; 
		}
		create building from: shape_file_buildings ;
		create road from: shape_file_roads with:[
			num_lanes::max(2, int(read("lanes"))),
			maxspeed::max(30.0 + rnd(5), (read("maxspeed_t")="urban:it")? 30.0+ rnd(5) : 50.0+rnd(5)),
			oneway::string(read("oneway"))]
			{
				if oneway !="yes"{
					
						create road {
							num_lanes <- myself.num_lanes ;
		                    shape <- polyline(reverse(myself.shape.points)) ;
		                    
		                    maxspeed <- myself.maxspeed ;
							length <- myself.length ;
		                    linked_road <- myself ;
		                    myself.linked_road <- self ;
						}					
					
				}
			}
		create road_node from: shape_file_nodes ;
		
		map<road,float> weight_map <- road as_map (each::(each.length+car_weight*length(each.all_agents)/each.length));		
		the_graph <- as_driving_graph (road, road_node) with_weights weight_map ;
		
		create car number: nb_vehicles {
			location <- one_of(road_node).location ;
			max_speed <- v_maxspeed #km / #h;
			vehicle_length <- 3.0 #m ;
		}
		create bus number: nb_bus_lines {
			max_speed <- 50 #km / #h;
			vehicle_length <- 8.0 #m ;
			current_source <- one_of(road_node) ;
			current_destination <- one_of(road_node) ;
			line_color <- one_of([#yellow, #red, #orange]);
			loop while: the_graph path_between (current_source, current_destination) = nil 
			or the_graph path_between (current_destination, current_source) = nil {
				current_source <- one_of(road_node) ;
				current_destination <- one_of(road_node) ;
			}
			location <- current_source.location ;
			add current_source to: bus_sources ;
			add current_destination to: bus_destinations ;
			// Computed path of buses are painted yellow shortest path in orange
			current_path <- compute_path (graph: the_graph, target: current_destination) ;
			/*loop i over: list(current_path.edges) {
				road(i).color <- line_color ;
			}
			loop i over: list((the_graph path_between (current_destination, current_source)).edges) {
				road(i).color <- #orange ;
			} */
		}
		 
		// INIZIALIZZAZIONE SEMAFORI
		// loop sui nodi della rete. Se le strade sono più di due il nodo diventa un semaforo
		int rndnum <- rnd(100) ;
		loop i over: road_node{
			//write i.index ;
			//write i.name ;
			
			//conto quante strade a doppio senso ci sono nel nodo
			loop j over: i.roads_in {
				// a quanto pare loopare su una lista di agenti strada non è abbastanza
				// per far capire che j è una strada 
				if (road(j).linked_road != nil) {
					i.linked_count <- i.linked_count + 1 ;
					
				}else{
					add j to: i.ordered_road_list  ; //aggiungo la strada alla lista ordinata solo se è oneway
				}
				
				
			}
			
			i.roads_in <- i.roads_in sort_by(-atan2((road(each).location.y-i.location.y) , (road(each).location.x-i.location.x)));
			i.ordered_road_list <<+ i.roads_out;
			//ordino la lista delle strade in modo che le strade siano in ordine antiorario
			//NON toccare la riga sotto
			i.ordered_road_list <- i.ordered_road_list sort_by (-atan2((road(each).location.y-i.location.y) , (road(each).location.x-i.location.x)) );
			
			
			//	controllo se il nodo è un incrocio: se ha più di 2 strade in ingresso è sempre un incrocio
			//	se ha 2 strade in ingresso a doppio senso e nessun'altra strada in uscita non è un incrocio
			if (length(i.roads_in) > 2 or length(i.roads_in) = 2 and !(i.linked_count = length(i.roads_out))) {
				i.is_traffic_light <- true ;
				i.timer <- rnd(i.green_time) ;	/* inizializzo randomicamente la fase del semaforo */
				i.timer <- rndnum ;		// con questo tutti i semafori hanno la stessa fase
				
				if (length(i.roads_in) = 3) {
					float angle <- atan2(i.roads_in[0].location.y - i.location.y, i.roads_in[0].location.x - i.location.x) - atan2(i.roads_in[1].location.y - i.location.y, i.roads_in[1].location.x - i.location.x) ;
					if (abs(angle) > 180 - t_ang_toll and abs(angle) < 180 + t_ang_toll) {
						// se le strade sono in direzioni opposte, allora il nodo è un semaforo a T sui rami 0 e 1
						add i.roads_in[0] to: i.roads_in_even ;
						add i.roads_in[1] to: i.roads_in_even ;
						add i.roads_in[2] to: i.roads_in_odd ;
					}
					angle <- atan2(i.roads_in[1].location.y - i.location.y, i.roads_in[1].location.x - i.location.x) - atan2(i.roads_in[2].location.y - i.location.y, i.roads_in[2].location.x - i.location.x) ;
					if (abs(angle) > 180 - t_ang_toll and abs(angle) < 180 + t_ang_toll) {
						// se le strade sono in direzioni opposte, allora il nodo è un semaforo a T sui rami 1 e 2
						add i.roads_in[1] to: i.roads_in_even ;
						add i.roads_in[2] to: i.roads_in_even ;
						add i.roads_in[0] to: i.roads_in_odd ;
					}
					angle <- atan2(i.roads_in[2].location.y - i.location.y, i.roads_in[2].location.x - i.location.x) - atan2(i.roads_in[0].location.y - i.location.y, i.roads_in[0].location.x - i.location.x) ;
					if (abs(angle) > 180 - t_ang_toll and abs(angle) < 180 + t_ang_toll) {
						// se le strade sono in direzioni opposte, allora il nodo è un semaforo a T sui rami 0 e 2
						add i.roads_in[2] to: i.roads_in_even ;
						add i.roads_in[0] to: i.roads_in_even ;
						add i.roads_in[1] to: i.roads_in_odd ;
					}
				}else{
					loop j from:0 to:length(i.roads_in)-1 step:2{
						add i.roads_in[j] to: i.roads_in_even;
					}
					loop j from:1 to:length(i.roads_in)-1 step:2{
						add i.roads_in[j] to: i.roads_in_odd;
					}
				}
				
				add i.roads_in_even to: i.stop ;
			}
			write (i.is_traffic_light) ? "is traffic light" : "is not traffic light";
		}
	}
	reflex update_outputs {
		remove from: trips index: 0 ;
		add (n_trips + trips at (length(trips) - 1)) to: trips ;
		n_trips <- 0 ;
	}
	reflex update_graph when: car_weight > 0.0 {
		map<road,float> weight_map <- road as_map (each::(each.length+car_weight*length(each.all_agents)/each.length));		
		the_graph <- the_graph with_weights weight_map ;
	}
}

// Veicoli definiti con skill advanced_driving
species vehicle skills: [driving] {
	rgb color <- rnd_color(255) ;
	
	float offset_distance<-0.2;
	init{
		vehicle_length <- 3.8 #m ;
		max_speed <- 150 #km / #h ;
		proba_respect_priorities <- 0.95 + rnd(0.04);
		proba_lane_change_up <- 0.2;
		proba_lane_change_down <- 0.2;
		
	}

	bool left_turn <- false;
	// Strada da cui arriva la macchina
	int i_in;
	// Strada dove vuole andare la macchina
	int i_out;
	int n;
	
	road road_now ;
	
	reflex move when: final_target != nil {
		
		road_now <- road(current_road) ;
		do drive ;
	}
	
	reflex left_lane when: left_lane_choice and road_now != current_road and final_target != nil{
		n <- length(road_node(current_target).ordered_road_list);
		left_turn <- false ;
		right_side_driving <- true ;
		acc_bias <- 1.0 ;
		if (n > 2){
			if (road(current_road).oneway != "yes"){
				i_in <- road_node(current_target).ordered_road_list
				index_of road(road(current_road).linked_road) ;
			}else{
				i_in <- road_node(current_target).ordered_road_list index_of road(current_road);
			}
			i_out <- road_node(current_target).ordered_road_list index_of road(next_road) ;
			left_turn <- mod(i_out-i_in+n,n) > min(2,n/2) ? true : false ;
			if (left_turn and current_road != nil)
			{
				// current_lane <- 0 /*road(current_road).num_lanes - 1*/ ;
				// right_side_driving <- false ;
				acc_bias <- -10.0 ;
			}else{
				// right_side_driving <- true ;
				acc_bias <- 1.0 ;
			}
		}
	}

	/*aspect default {
	draw circle(dimension) color: color ;
	}*/
	
	//aspetto rettangolare con freccia direzionale
	aspect rect {
		if (current_road != nil) {
			point loc <- eval_loc() ;
			draw rectangle(vehicle_length*dimension, dimension #m)
			at: loc color: color rotate: heading border: #black;
			draw triangle(1 #m) at: loc color: #white rotate: heading + 90 ;
		}
	}
	// sposto le auto in base alla corsia occupata
	point eval_loc {
		float val <- (road(current_road).num_lanes - current_lane) + offset_distance ;
		val <- on_linked_road ? val * - 1 : val ;
		if (val = 0) {
			return location ; 
		} else {
			return (location + {cos(heading + 90) * val, sin(heading + 90) * val}) ;
		}
	}

}

species car parent:vehicle{
	rgb color <- rnd_color(255) ;
	list<path> a_path_list ;
	list<road> edge_list ;
	list<road_node> node_list ;
	
	float offset_distance<-0.2;
	init{
		vehicle_length <- 3.8 #m ;
		max_speed <- 150 #km / #h ;
		proba_respect_priorities <- 0.95 + rnd(0.04);
		proba_lane_change_up <- 0.2;
		proba_lane_change_down <- 0.2;
		
	}

	reflex time_to_go when: final_target = nil {
		// se il veicolo si blocca all'arrivo ha una probabilità di cambiare posizione
		// questo serve nei casi in cui il nodo di arrivo ha solo strade in ingresso
		// per mappe grandi è raro che succeda, ma non in mappe piccole 
		if (length(car) < (1.0 - cos(360 * (current_date.hour*3600 +
		current_date.minute*60 + current_date.second) / 7200.0) / 2.0)*nb_vehicles){
			create car number: 2 {
				location <- one_of(building).location ;
				current_path <- compute_path (graph: the_graph, target: one_of(road_node)) ;
				max_speed <- v_maxspeed #km / #h;
				vehicle_length <- 3.0 #m ;
			}
		}
		n_trips <- n_trips + 1 ;
		do die ;
	}
}

species bus parent:vehicle skills: [fipa] {
	rgb color <- #yellow ;
	road_node current_source ;
	road_node current_destination ;
	rgb line_color;

	
	float offset_distance<-0.3;
	init{
		vehicle_length <- 8.5 #m ;
		max_speed <- 50 #km / #h ;
		proba_respect_priorities <- 1.0;
		proba_lane_change_up <-0.01;
		proba_lane_change_down <- 0.01;	
	}
	
	reflex time_to_go when: final_target = nil {
		if (length(bus) < (2.0 - cos(360 * (current_date.hour*3600 +
		current_date.minute*60 + current_date.second) / 7200.0))*nb_bus_min){
			// creo un bus che percorre il tragitto inverso
			create bus {
				location <- myself.location ;
				// aggiorno le variabili di partenza e arrivo del bus
				int i <- int(rnd(0,nb_bus_lines-1)) ;
				current_source <- bus_destinations[i] ;
				current_destination <- bus_sources[i] ; 
				// garantisco che partenza e destinazione siano correttamente accoppiate
				
				current_path <- compute_path (graph: the_graph, target: current_destination) ;
				
				
				max_speed <- 50 #km / #h;
				vehicle_length <- 8.5 #m ;
			}
			// creo un bus che percorre lo stesso tragitto
			create bus {
				road_now <- nil ;
				location <- myself.current_source.location ;
				// aggiorno le variabili di partenza e arrivo del bus
				int i <- int(rnd(0,nb_bus_lines-1)) ;
				current_source <- bus_sources[i] ;
				current_destination <- bus_destinations[i] ;
				current_path <- compute_path (graph: the_graph, target: current_destination) ;
				max_speed <- 50 #km / #h;
				vehicle_length <- 8.5 #m ;
			}
		}
		n_trips <- n_trips + 1 ;
		do die ;
	}

	reflex ask_green_light when: current_road != road_now and current_target != final_target and current_target != nil and road_node(current_target).is_traffic_light{
		// chiudo eventuali conversazioni aperte
		// loop i over: conversations {
		// 	do end_conversation message: [i.participants[1]] ;
		// }
		//write "cycle " + cycle + " " + name + ": ask for green light at " + current_target.name ;
		do start_conversation to: [current_target] protocol: "fipa-request" performative: "request" contents: [self.name] ;
	}
}

species road skills: [road_skill] {
	rgb color <- #blue ;
	string oneway ;
	aspect base {
		draw shape color: color ;
	}
	float length <- 0.0 ;
	init {
		loop i over: segment_lengths {
			length <- length+ float(i) ;
		}
	}
}

// specie road_node con intersection_skill
species road_node skills: [intersection_skill, fipa] {
	bool is_traffic_light <- false ;
	int timer ;
	int linked_count <- 0 ;	//	numero di strade a doppio senso di marcia, necessario per determinare se un nodo è un incrocio
	int switch_time <- 20 + rnd(20);
	int green_time <- int(switch_time / step #s) ;
	int red_time <- int(switch_time / step #s) ;
	bool road_even_ok <- false ;	//	quando true è verde per le strade con indice pari
	rgb color <- #green ;
	list roads_in_even <- [] ;	//	sono le strade in ingresso con indice pari
	list roads_in_odd <- [] ;	//	sono le strade in ingrsso con indice dispari
	list ordered_road_list <-[]; // strade ordinate con solo out in caso di linked
	float count_odd <- 0.0 ;
	float count_even <- 0.0 ;
	int tolerance <-0;
	list<road_node> nearby_nodes <- [] ;
	bus nearest_bus <- nil ;
	bool bus_on_road <- false ;
	
	init{
		loop i over: roads_in {
			add road_node(road(i).source_node) to: nearby_nodes ; 
		}
	}


	reflex gaza_cleansing when: is_traffic_light{
		loop i over: requests {
			if /*dead(i.sender) or */bus(i.sender).current_road in roads_out {
				//write "cycle " + cycle + " " + name + ": terminate conversation with bus " + i.sender.name ;
				do agree message: i contents: ["Crossed the road"] ;
				if i.sender = nearest_bus {
					nearest_bus <- nil ;
					bus_on_road <- false ;
				}
			}
		}
	}



	// reflex clean_dead{
	// 	loop i over: requests{
	// 		if dead(i.sender){
	// 			//remove i from: requests;
	// 			do end_conversation message: i contents: [ ('Rebound goodbye from' + name) ] ;
	// 		}
	// 	}
	// 	if dead(nearest_bus){
	// 		nearest_bus<-nil;
	// 	}
	// }

	reflex read_mailbox when: !empty(requests) /*and !bus_on_road*/ {
		//write "cycle " + cycle + " " + name + ": Found requests in mailbox" + string(requests) ;
		// float timex <- compute_bus_time(requests[0].sender) ;
		
		bus_on_road <- true ;
		nearest_bus <- requests[0].sender ;
		
		loop i over: requests {
			
			if(dead(i.sender)){
				// remove from: requests index: requests index_of i;
				
			}
			else if bus(i.sender).distance_to_current_target < nearest_bus.distance_to_current_target {
				nearest_bus <- i.sender ;
			}
		}
		//write "cycle " + cycle + " " + name + ": nearest bus is " + nearest_bus.name ;
	}
	

	// reflex terminate_conversation when: nearest_bus != nil and !dead(nearest_bus) and nearest_bus.current_road in roads_out {
	// 	write "cycle " + cycle + " " + name + ": terminate conversation with bus " + nearest_bus.name ;
	// 	//do agree message: requests[collect(requests, each.sender) index_of nearest_bus] contents: ["ok"] ;
	// 	if !(nearest_bus in collect(requests, each.sender)) {
	// 		write "cycle " + cycle + " " + name + " successfully terminated communication with " + nearest_bus.name ;
	// 		nearest_bus <- nil ;
	// 		bus_on_road <- false ;
	// 	} else {
	// 		write "cycle " + cycle + " " + "somtin wong" ;
	// 	}
	// 	/*
	// 		Da' problemi quando il bus arriva a destinazione perche' nearest_bus muore.
	// 		Risolvo se metto current_target != final_target come condizione alla richiesta di verde da parte del bus?
	// 	*/
	// }
	
	reflex classic_update_state when: is_traffic_light {
		
		if intelligent_g{

			timer <-timer+1;
			count_even <- 0.0 ;
			count_odd <- 0.0 ;
			loop k over: roads_in_even{
				// count_even+<- count(road(k).all_agents,true);
				loop l over: road(k).segment_lengths {
				}
				count_even <- count_even + float ( length ( road(k).all_agents ) / ( road(k).length ) ) ;
			}
			loop l over: roads_in_odd{
				// count_odd+<- count(road(l).all_agents,true);
				count_odd <- count_odd + float ( length ( road(l).all_agents ) / ( road(l).length ) ) ;
			}
			if road_even_ok and count_odd >= count_even + tolerance and timer >= min_timer or timer >= max_timer{
				do switch_state ;
			}
			if !road_even_ok and count_odd + tolerance <= count_even  and timer >= min_timer or timer >= max_timer{
				do switch_state ;	
			}
			
			
			
		}/*else{
			if !empty(requests) {
				// timer <- tiemx ;
			} else {
				timer <- timer + 1 ;
				if (!road_even_ok and timer >= green_time) {
					do switch_state ;			
				} else if (timer >= red_time) {
					do switch_state ;
				}
			}
			
		}*/
		if stupid_g {
			timer <- timer + 1 ;
			if bus_on_road and !dead(nearest_bus) {
				if nearest_bus.road_now in roads_in_even {
					if !road_even_ok {
						do switch_state ;
					}
				} else if road_even_ok {
					do switch_state ;
				}
			} else {
				if !road_even_ok and timer >= green_time {
					do switch_state ;
				} else if timer >= red_time {
					do switch_state ;
				}
			}
		}
	}
	
	int switch_state {
		stop[] <- road_even_ok? roads_in_even : roads_in_odd ;	//	fermo le strade pari se finora avevano il verde
		road_even_ok <- !road_even_ok ;							//	altrimenti fermo le dispari, poi aggiorno road_even_ok
		color <- color = #red ? #green : #red ;
		timer <- 0 ;
		return 0 ;
	}

	float compute_bus_time (bus bus_in) {
		float bus_time <- 0.0 ;
		bus_time <- road(bus_in.current_road).length / bus_in.max_speed / 3.6 ;
		return bus_time ;
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

experiment TrafficLightModel type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_nodes category: "GIS" ;
	// parameter "Probability of respawn:" var: respawn_prob category: "BOH" ;
	parameter "Vehicle dimension:" var: dimension ;
	parameter "Mean number of vehicles:" var: nb_vehicles ;
	parameter "Number of bus lines:" var: nb_bus_lines ;
	parameter "Minimum number of buses:" var: nb_bus_min ;
	parameter "Maximum speed:" var: v_maxspeed ;
	parameter "Intelligent traffic lights:" var:intelligent_g ;
	parameter "Stupid traffic lights:" var:stupid_g ;
	parameter "T-junction angle tolerance:" var: t_ang_toll ;
	// parameter "Minimum timer for traffic light:" var: min_timer ;
	parameter "User switch:" var: left_lane_choice ;
	parameter "proba_rerouting" var: proba_rerouting ;
	parameter "Weight" var: car_weight ;
		
	output {
		display city_display type:2d {
			species building aspect: default ;
			species road aspect: base ;
			species car aspect: rect ;
			species bus aspect: rect ;
			species road_node aspect:default ;
		}
		monitor "Number of trips" value: n_trips ;
		display "Symulation informations" refresh: every(60#cycles) type: 2d {
			chart "Number of vehicles" type: series size: {0.5,0.5} position: {0,0} {
				data "number of cars" value: length(car) color: #red ;
				data "number of buses" value: length(bus) color: #blue ;
			}
			chart "Successful trips" type: series size: {0.5,0.5} position: {0,0.5} {
				data "number of successful trips" value: trips at (length(trips) - 1) color: #green ;
				data "ten second average variation" value: trips at (length(trips) - 1) - trips at 0
				color: #purple use_second_y_axis: true ;
			}
         	chart "Road Status" type: series size: {0.5, 0.5} position: {0.5, 0.5} {
                 data "Mean vehicle speed" value: mean (car collect each.speed)  *3.6 style: line color: #purple ;
                 data "Max speed" value: car max_of (each.speed *3.6) style: line color: #red ;
	     }
	     chart "Road Status" type: series size: {0.5, 0.5} position: {0.5, 0} {
                 data "Nb stopped vehicles" value:  car count (each.speed <1) / (length(car)+1)  style: line color: #purple ;
                 
	     }
         
		}
	}
}

experiment boolBatch type: batch until: (cycle = 7200) keep_seed: true {
	parameter "Left Lane Choice" var: left_lane_choice among: [true, false] ;
	parameter "Intelligent Traffic Lights" var: intelligent_g among: [true, false] ;
	method exploration ;
	bool delete_csv <- delete_file("../results/trips.csv") ;
	reflex save_trips {
		loop i over: simulations {
			save [i.intelligent_g,i.left_lane_choice,i.n_trips] format: "csv" to: "../results/trips.csv"
			rewrite: false ;
		}
	}
}

experiment min_light type: batch until: (cycle = 7200) keep_seed: true {
	parameter "Minimum light time" var: min_timer min: 10 max: 45 step: 5 ;
	method exploration ;
	bool delete_csv <- delete_file("../results/min_light.csv") ;
	reflex save_trips {
		loop i over: simulations {
			save [i.min_timer,i.n_trips] format: "csv" to: "../results/min_light.csv"
			rewrite: false ;
		}
	}
}

experiment min_max_light type: batch until: (cycle = 7200) keep_seed: true {
	parameter "Minimum light time" var: min_timer min: 15 max: 45 step: 10 ;
	parameter "Maximum light time" var: max_timer min: 60 max: 180 step: 40 ;
	method exploration ;
	bool delete_csv <- delete_file("../results/min_max_light.csv") ;
	reflex save_trips {
		loop i over: simulations {
			save [i.min_timer,i.max_timer,i.n_trips] format: "csv" to: "../results/min_max_light.csv"
			rewrite: false ;
		}
	}
}

experiment test type: batch until: (cycle = 6*3600) keep_seed: true {
	parameter "Rerouting probability" var: proba_rerouting min: -11/5 max: 0.0 step: 1/5 ;
	method exploration ;
	bool delete_csv <- delete_file("../results/test1.csv") ;
	reflex save_trips {
		loop i over: simulations {
			save [10 ^ (i.proba_rerouting) * 100, last (i.trips), 100 * mean (i.car count (each.speed<1) / (length(i.car) + 1))] format: "csv" to: "../results/test1.csv"
			rewrite: false ;
		}
	}
}

experiment car_weight type: batch until: (cycle = 6*3600) keep_seed: true {
	parameter "Car weight" var: car_weight min: 0.0 max: 3500.0 step: 100.0 ;
	method exploration ;
	// bool delete_csv <- delete_file("../results/car_weight.csv") ;
	reflex save_trips {
		loop i over: simulations {
			save [i.car_weight, last (i.trips), 100 * mean (i.car count (each.speed<1) / (length(i.car) + 1))] format: "csv"
			to: "../results/car_weight"+string(#now, 'yyyy-MM-dd-HH.mm.ss')+".csv" rewrite: false ;
		}
	}
}