/**
* Name: Loading of GIS data (buildings and roads)
* Author:
* Description: first part of the tutorial: Road Traffic
* Tags: gis
*/

model tutorial_gis_city_traffic

global {
	file shape_file_buildings <- file("../includes/carta_sintesi_geo.shp");
	file shape_file_roads <- file("../includes/manto_stradale_2009_geo.shp");
	file shape_file_bounds <- file("../includes/carta_sintesi_geo.shp");
	geometry shape <- envelope(shape_file_bounds);
	float step <- 10 #mn;
	
	init {
		create carta_sintesi_geo from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			if type="Industrial" {
				color <- #blue ;
			}
		}
		create road from: shape_file_roads ;
		
		create goal  {
			 location <- any_location_in (one_of(road)); 
		}
		create vehicle number: 100 {
			 target <- one_of (goal) ; 
			 location <- any_location_in (one_of(road));
		} 
	}
}

species carta_sintesi_geo {
	string type; 
	rgb color <- #gray  ;
	
	aspect base {
		draw shape color: color ;
	}
}

species goal{aspect default {
		draw circle(3) color:#red;
	}}
species vehicle {
	goal target;
	aspect default {
		draw circle(3) color: #green;
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
		display city_display type:3d {
			species carta_sintesi_geo aspect: base ;
			species road aspect: base ;
			species vehicle aspect:default;
		}
	}
}