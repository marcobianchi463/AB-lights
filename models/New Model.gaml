/**
* Name: Loading of GIS data (buildings and roads)
* Author:
* Description: first part of the tutorial: Road Traffic
* Tags: gis
*/

model tutorial_gis_city_traffic

global {
	file shape_file_buildings <- file("../includes/torino/shape/buildings.shp");
	file shape_file_roads <- file("../includes/torino/shape/roads.shp");
	file shape_file_bounds <- file("../includes/torino/shape/buildings.shp");
	geometry shape <- envelope(shape_file_bounds);
	float step <- 10 #mn;
	
	init {
		create building from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			if type="Industrial" {
				color <- #blue ;
			}
		}
		create road from: shape_file_roads ;
		list<building> buildings_list <- building;
		create vehicle number: 10{
			starting_position<-one_of(building);
		}
	}
}

species building {
	string type; 
	rgb color <- #gray  ;
	
	aspect base {
		draw shape color: color ;
	}
}

species road  {
	rgb color <- #blue ;
	aspect base {
		draw shape color: color ;
	}
}

species vehicle skills:[moving]{
	rgb color <- #red;
	aspect base {
		draw circle(100) color: color;
	}
	building starting_position;
}

experiment road_traffic type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;
		
	output {
		display city_display type:3d {
			species building aspect: base ;
			species road aspect: base ;
			species vehicle aspect: base ;
		}
	}
}