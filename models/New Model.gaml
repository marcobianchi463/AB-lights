/**
* Name: Loading of GIS data (buildings and roads)
* Author:
* Description: first part of the tutorial: Road Traffic
* Tags: gis
*/

model tutorial_gis_city_traffic

global {
	//file shape_file_buildings <- file("../includes/carta_sintesi_geo.shp");

	file shape_file_buildings <- file("../includes/mygeodata/qgis/build.shp"); 
	file shape_file_roads <- file("../includes/mygeodata/qgis/split-roads.shp");
	file shape_file_nodes <- file("../includes/mygeodata/qgis/junctions.shp");
	geometry shape <- envelope(shape_file_roads);
	
	float step <- 1 #s;
	graph the_graph;
	init {

		/*create carta_sintesi_geo from: shape_file_buildings with: [type::string(read ("NATURE"))] {

			if type="Industrial" {
				color <- #blue ;
			}
		}*/
		create building from: shape_file_buildings;

		create road from: shape_file_roads ;

		create goal from: shape_file_nodes ; //creo tutti i nodi

		//creazione grafico da strade
		the_graph <- as_driving_graph(road, goal) ;
		// create goal from: the_graph.vertices;
		create vehicle number: 80 {
			 target <- any_location_in(one_of (building)) ; 
			 location <- any_location_in (one_of(road)) ;
			 speed <- 30 #km / #h;
			 vehicle_length <- 3.0 #m ;
			 max_acceleration <- 0.5 + rnd(500) / 1000 ;
			 speed_coeff <- 1.2 - (rnd(500) / 1000) ;
			 right_side_driving <- true ;
			 security_distance_coeff <- 3 - (rnd(2000) / 1000) ;
		} 
		write the_graph;
		write "Edges : "+length(the_graph.edges);
		write "Nodes : "+length(the_graph.vertices);
	}
}


species goal skills: [intersection_skill]{
	bool is_traffic_light <- true;
	int time_to_change <- 10;
	int counter <- rnd(time_to_change);
	/*reflex dynamic when: is_traffic_light {
		counter <- counter + 1;
		if (counter >= time_to_change) {
			counter <- 0;
			stop[0] <- empty(stop[0])? roads_in : [];
		}
	}*/


	aspect default {
		draw circle(2) color:#red;
	}
}
species building{
	rgb color <- #gray  ;
	aspect default {
		draw shape color:color;
	}
}
species vehicle skills: [advanced_driving]{
	point target;
	int tries;
	
	reflex {
		loop while: current_path = nil {
		    	target <- any_location_in(one_of (building)) ; 
		  		do goto on:the_graph target:target speed:3;
		  		tries <- tries +1;
		  		write "Ciao";
		  		if tries>20 {
		  			location <- any_location_in(one_of(road));
		  		}
			}
		write "Vehicle at: " + location + " moving towards: " + target;
		do goto on:the_graph target:target speed:3;
		//do wander speed:10.0 on:the_graph;
		//do move;
		//do drive;
	}
	aspect default {
	draw circle(3) color: #green;
	}
}



species road skills: [road_skill]{
	rgb color <- #blue ;
	aspect base {
		draw shape color: color ;
	}
}


experiment road_traffic type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_nodes category: "GIS" ;
		
	output {
		display city_display type:2d {
			species building aspect: default ;
			species road aspect: base ;
			species vehicle aspect: default ;
			species goal aspect:default;
		}
	}
}