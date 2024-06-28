//
// file: frontend_amb.csc
// description: clientside ambient script for frontend: setup ambient sounds, etc.
// scripter: 		(initial clientside work - laufer)
//

#include clientscripts\_utility; 
#include clientscripts\_ambientpackage;
#include clientscripts\_music;
#include clientscripts\_busing;
#include clientscripts\_audio;

main()
{
	declareAmbientRoom("frontend", true );
		setAmbientRoomReverb( "frontend", "black_bridge_room", 1, 1 );
		setAmbientRoomContext( "frontend", "ringoff_plr", "indoor" );	
		setAmbientRoomTone( "frontend", "amb_frontend_bg", 1, 1 );
	declareAmbientPackage( "frontend" );
	
	declareAmbientRoom("frontend_briefing_room" );
		setAmbientRoomReverb( "frontend_briefing_room", "black_bridge_room", 1, 1 );
		setAmbientRoomContext( "frontend_briefing_room", "ringoff_plr", "indoor" );	
		setAmbientRoomTone( "frontend_briefing_room", "amb_bg_briefing_room", 1, 1 );
	declareAmbientPackage( "frontend_briefing_room" );
	
	declareAmbientRoom("frontend_osprey" );
		setAmbientRoomReverb( "frontend_osprey", "black_bridge_room", 1, 1 );
		setAmbientRoomContext( "frontend_osprey", "ringoff_plr", "indoor" );	
		setAmbientRoomTone( "frontend_osprey", "amb_bg_osprey_internal", 1, 1 );
	declareAmbientPackage( "frontend_osprey" );
	
	//MUSIC STATE SETUP
	
	declaremusicState ("FRONT_END_START");
		musicAliasloop ("mus_fe_start", 2, 4);
		
	declaremusicState ("FRONT_END_MAIN");
		musicAliasloop ("mus_fe_main", 2, 4);	
		
	declaremusicState ("MUS_FE_STRIKEFORCE");
		musicAliasloop ("null", 4, 2);
		
	declaremusicState ("CREDITS");
		musicAliasloop ("mus_fe_credits", 0, 2);	
		
	declaremusicState ("FRONT_END_NO_MUSIC");		
		musicAliasloop ("null", 0, 0);	
		
	level thread menu_snapshot_sets();
}
menu_snapshot_sets()
{
	level thread menu_snapshot_noamb();
	level thread menu_snapshot_amb();
}
menu_snapshot_noamb()
{
	while(1)
	{
		level waittill( "sndNOAMB" );
		snd_set_snapshot( "spl_frontend_amb_mute" );
	}
}
menu_snapshot_amb()
{
	while(1)
	{
		level waittill( "sndAMB" );
		snd_set_snapshot( "default" );
	}
}
