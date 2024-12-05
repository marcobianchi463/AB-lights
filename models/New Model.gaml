/**
* Name: Loading of GIS data (buildings and roads)
* Author:
* Description: first part of the tutorial: Road Traffic
* Tags: gis
*/

model tutorial_gis_city_traffic

global {
	//file shape_file_buildings <- file("../includes/carta_sintesi_geo.shp");
	file shape_file_buildings <- file("../includes/mygeodata/map/buildings-polygon.shp"); 
	file shape_file_roads <- file("../includes/mygeodata/map/roads-line.shp");
	file shape_file_bounds <- file("../includes/mygeodata/map/buildings-polygon.shp");
	geometry shape <- envelope(shape_file_roads);
	float step <- 10 #mn;
	graph the_graph;
	init {
		/*create carta_sintesi_geo from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			if type="Industrial" {
				color <- #blue ;
			}
		}*/
		create building from: shape_file_buildings;

		create road from: shape_file_roads ;
		//test 

		//creazione grafico da strade
		the_graph <- as_edge_graph(road);
		create goal from: the_graph.vertices; 
		create vehicle number: 800 {
			 target <- any_location_in(one_of (building)) ; 
			 location <- any_location_in (one_of(road));
			 
		//
		} 
		write the_graph;
		write "Edges : "+length(the_graph.edges);
		write "Nodes : "+length(the_graph.vertices);
	}
}


species goal{
	aspect default {
		draw circle(3) color:#red;
	}
}
species building{
	rgb color <- #gray  ;
	aspect default {
		draw shape color:color;
	}
}
species vehicle skills: [moving]{
	point target;
	int tries;
	
	reflex goto {
		loop while: current_path = nil {
		    	target <- any_location_in(one_of (building)) ; 
		  		do goto on:the_graph target:target speed:0.1;
		  		tries <- tries +1;
		  		write "Ciao";
		  		if tries>20 {
		  			location <- any_location_in(one_of(road));
		  		}
			}
		write "Vehicle at: " + location + " moving towards: " + target;
		do goto on:the_graph target:target speed:0.1;
		//do wander speed:10.0 on:the_graph;
		//do move;
	}
	aspect default {
		draw circle(5) color: #green;
	}
}



species road  {
	rgb color <- #blue ;
	aspect base {
		draw shape color: color ;
	}
}


experiment road_traffic type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;
		
	output {
		display city_display type:2d {
			species building aspect: default ;
			species road aspect: base ;
			species vehicle aspect:default;
			species goal aspect:default;
		}
	}
}