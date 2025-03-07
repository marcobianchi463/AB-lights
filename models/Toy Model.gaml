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
	int nb_vehicles <- 240 ;
	float respawn_prob <- 1.0 ;
	int dimension <- 1 ;
	int v_maxspeed <- 150 ;
	bool intelligent_g <- true ;
	float t_ang_toll <- 10.0 ;
	int min_timer <- 15 ;
	
	bool user_switch <- true ;

	graph the_graph ;
	init {
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
		                    color <- #green;
		                    maxspeed <- myself.maxspeed ;
		                    linked_road <- myself ;
		                    myself.linked_road <- self ;
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
	int i_in;
	int i_out;
	int n;
	
	road road_now ;
	
	reflex time_to_go when: final_target = nil {
		// se il veicolo si blocca all'arrivo ha una probabilità di cambiare posizione
		// questo serve nei casi in cui il nodo di arrivo ha solo strade in ingresso
		// per mappe grandi è raro che succeda, ma non in mappe piccole 
		if (flip(respawn_prob)){
			location <- one_of(building).location ;
		}
		current_path <- compute_path (graph: the_graph, target: one_of(road_node)) ;
	}
	reflex move when: final_target != nil {
		//if dot_product({cos(heading), sin(heading)},{0,0}){
		//	//imposta nelle corsie utilizzabili quella con indice maggiore(più interna)
		//	allowed_lanes <- [road(current_road).num_lanes-1];
		//}
		road_now <- road(current_road) ;
		do drive ;
	}
	
	reflex left_lane when: user_switch and road_now != current_road and final_target != nil{
		n <- length(road_node(current_target).ordered_road_list);
		left_turn <- false ;
		right_side_driving <- true ;
		acc_bias <- 1.0 ;
		if (n > 2){
			if (road(current_road).oneway != "yes"){
				i_in <- road_node(current_target).ordered_road_list index_of road(road(current_road).linked_road) ;
			}else{
				i_in <- road_node(current_target).ordered_road_list index_of road(current_road);
			}
			i_out <- road_node(current_target).ordered_road_list index_of road(next_road) ;
			if (i_in < i_out){
				left_turn <- i_out-i_in>min(2,n/2) ? true : false ;
			}else{
				left_turn <- n-(i_in-i_out)>min(2,n/2) ? true : false ;
			}
			if (left_turn and current_road != nil)
			{
//				current_lane <- 0 /*road(current_road).num_lanes - 1*/ ;
				// right_side_driving <- false ;
				acc_bias <- -10.0 ;
			}else{
				// right_side_driving <- true ;
				acc_bias <- 1.0 ;
			}
		}
	}

	aspect default {
	draw circle(dimension) color: color ;
	}
	
	//aspetto rettangolare con freccia direzionale
	aspect rect {
		if (current_road != nil) {
			point loc <- eval_loc() ;
			draw rectangle(vehicle_length*dimension, dimension #m) at: loc color: color rotate: heading border: #black;
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
	int switch_time <- 20 + rnd(20);
	int green_time <- int(switch_time #s) ;
	int red_time <- int(switch_time #s) ;
	bool road_even_ok <- true ;	//	quando true è verde per le strade con indice pari
	rgb color <- #green ;
	list roads_in_even <- [] ;	//	sono le strade in ingresso con indice pari
	list roads_in_odd <- [] ;	//	sono le strade in ingrsso con indice dispari
	list ordered_road_list <-[]; // strade ordinate con solo out in caso di linked
	int count_odd<-0;
	int count_even<-0;
	int tolerance <-0;
//	int min_timer <-15;
	

	
	reflex classic_update_state when: is_traffic_light {
		
		if intelligent_g{

			timer <-timer+1;
			loop k over: roads_in_even{
				// count_even+<- count(road(k).all_agents,true);
				count_even +<- length(road(k).all_agents);
			}
			loop l over: roads_in_odd{
				// count_odd+<- count(road(l).all_agents,true);
				count_odd +<- length(road(l).all_agents);
			}
			if road_even_ok and count_odd >= count_even + tolerance and timer >= min_timer{
				timer <- 0 ;
				color <- #green ;
				do switch_state ;
			}else if !road_even_ok and count_odd + tolerance <= count_even  and timer >= min_timer{
				timer <- 0 ;
				color <- #red ;
				do switch_state ;	
			}
			
			
			
		}else{
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
	parameter "Intelligent traffic lights:" var:intelligent_g ;
	parameter "T-junction angle tolerance:" var: t_ang_toll ;
	parameter "Minimum timer for traffic light:" var: min_timer ;
	parameter "User switch:" var: user_switch ;
		
	output {
		display city_display type:2d {
			species building aspect: default ;
			species road aspect: base ;
			species vehicle aspect: rect ;
			species road_node aspect:default ;
		}
	}
}