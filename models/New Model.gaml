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
	geometry shape <- envelope(shape_file_bounds);
	float step <- 10 #mn;
	graph the_graph;
	init {
		create carta_sintesi_geo from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			if type="Industrial" {
				color <- #blue ;
			}
		}

		create road from: shape_file_roads ;
		//test 

		//creazione grafico da strade
		the_graph <- as_edge_graph(road);
		create goal from: the_graph.vertices; 
		create vehicle number: 30 {
			 target <- one_of (goal) ; 
			 location <- any_location_in (one_of(road));
		} 
		write the_graph;
		write "Edges : "+length(the_graph.edges);
		write "Nodes : "+length(the_graph.vertices);
	}
}

species carta_sintesi_geo {
	string type; 
	rgb color <- #gray  ;
	
	aspect base {
		draw shape color: color ;
	}
}

species goal{
	aspect default {
		draw circle(3) color:#red;
	}
}
species vehicle skills: [moving]{
	goal target;
	path my_path;
	reflex goto {
		write "Vehicle at: " + location + " moving towards: " + target.location;
		do goto on:the_graph target:target.location speed:0.1;
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
			species carta_sintesi_geo aspect: base ;
			species road aspect: base ;
			species vehicle aspect:default;
			species goal aspect:default;
		}
	}
}