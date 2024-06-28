// Test clientside script for frontend

#include clientscripts\_callbacks;
#include clientscripts\_utility;
#include clientscripts\_music;
#include clientscripts\frontend_menu;
#include clientscripts\_qrcode;

// Script mover flags
#define CLIENT_FLAG_FROSTED_GLASS 11
#define CLIENT_FLAG_CLOCK 12
#define CLIENT_FLAG_MAP_MONITOR		13
#define CLIENT_FLAG_HOLO_RED		14
#define CLIENT_FLAG_HOLO_VISIBLE	15
	
// Vehicle flags.
#define CLIENT_FLAG_SPEEDING_OSPREY 11
	
#define UNUSED 0
	
main()
{
	// Keep this here for CreateFx
	clientscripts\frontend_fx::main();
	
	level.m_map_monitors = [];
	
	// _load!
	clientscripts\_load::main();

	//thread clientscripts\_fx::fx_init(0);
	thread clientscripts\_audio::audio_init(0);

	thread clientscripts\frontend_amb::main();

	// This needs to be called after all systems have been registered.
	waitforclient(0);

	default_settings();
	frontend_menu_init();
	
	register_clientflag_callback( "scriptmover", CLIENT_FLAG_CLOCK, ::world_clock_run );
	register_clientflag_callback( "scriptmover", CLIENT_FLAG_MAP_MONITOR, ::map_monitor_run );
	register_clientflag_callback( "scriptmover", CLIENT_FLAG_HOLO_RED, ::set_hologram_red );
	register_clientflag_callback( "scriptmover", CLIENT_FLAG_HOLO_VISIBLE, ::set_hologram_shown );
	
	register_clientflag_callback( "vehicle", CLIENT_FLAG_SPEEDING_OSPREY, ::set_speeding_osprey );

	//-- bink on the screens
	start_env_movie();
	
	// all world maps share this same data.
	//
	{
		level.world_map = SpawnStruct();
	
		// translate x, translate y, rotation, scale
		level.world_map.transform = array( 0, 0, 0, 1.0 );
		
		// valid range 0-3, 3 = off.
		level.world_map.tint = array( 0, 0, 0, 0, 0, 0 );
		
		// valid range: 0 = off, 1 = on
		level.world_map.marker_toggle = array( 0, 0, 0, 0, 0, 0 );
		level.world_map.widget_toggle = array( 0, 0, 0, 0, 0, 0 );
		
		// valid range: 0-6, 6 = off
		level.world_map.main_icon = 6;
	}
	
	/#PrintLn("*** Client : frontend is running...");#/
}

stop_env_movie()
{
	if (IsDefined(level.screen_bink))
	{
		//level.nextMusicState = "FRONT_END_NO_MUSIC";
		//level notify("new_music");
		StopBink(level.screen_bink);
		level.screen_bink=undefined;
	}
}

start_env_movie()
{
	//level.nextMusicState = "FRONT_END_MAIN";
	//level notify("new_music");
	level.screen_bink = PlayBink( "frontend_screen", 2 );
}

world_clock_get_offset()
{
	if ( IsSubStr( self.model, "chicago" ) )
	{
		return -6;
	}
	else if ( IsSubStr( self.model, "los_angeles" ) )
	{
		return -8;
	}
	else if ( IsSubStr( self.model, "new_york" ) )
	{
		return -5;
	}
	else if ( IsSubStr( self.model, "tokyo" ) )
	{
		return 9;
	}
	else if ( IsSubStr( self.model, "hong_kong" ) )
	{
		return 8;
	}
	
	return 0;
}

#define SHADER_DIGIT_X(num) (num%5)
#define SHADER_DIGIT_Y(num) Floor(num/5)
	
world_clock_run( localClientNum, set, newEnt )
{
	self mapShaderConstant( localClientNum, 0, "ScriptVector0" );
	
	gmt_offset = self world_clock_get_offset();
	
	/#
		if ( isdefined( self.script_noteworthy ) )
	    {
	    	PrintLn( "Client: clock digit running: " + self.script_noteworthy );
	    }
	#/
	
	while ( true )
	{
		// the format should be an array (hour, min, sec), military time
		//	if we pass in a 1 then we'll get GMT 0 London time, else we get the local time on the kit
		curr_time = GetSystemTime( 1 );
	
		hours = Int(curr_time[0]);
		minutes = Int(curr_time[1]);
		seconds = Int(curr_time[2]);
		
		// adjust for time zone.
		hours += gmt_offset;
		
		// Clamp 0-23
		{
			if ( hours < 0 )
				hours += 24;
			else if ( hours >= 24 )
				hours -= 24;
		}
		
		time = array( Floor( hours / 10 ), hours % 10, Floor( minutes / 10 ), minutes % 10);
		
		// Shift the numbers down one (or back to 9 for zero).
		for ( i = 0; i < time.size; i++ )
		{
			time[i] = Float(Int(time[i] + 9) % 10);
		}
		
		self setShaderConstant( localClientNum, 0, time[0], time[1], time[2], time[3] );
		
		wait 1.0;
	}
}

refresh_map_shaders( localClientNum )
{
	self SetShaderConstant( localClientNum, 0, level.world_map.transform[0],		level.world_map.transform[1],		level.world_map.transform[2],		level.world_map.transform[3] );
	self SetShaderConstant( localClientNum, 1, level.world_map.tint[0],				level.world_map.tint[1],			level.world_map.tint[2],			level.world_map.tint[3] );
	self SetShaderConstant( localClientNum, 2, level.world_map.tint[4],				level.world_map.tint[5],			level.world_map.marker_toggle[0],	level.world_map.marker_toggle[1] );
	self SetShaderConstant( localClientNum, 3, level.world_map.marker_toggle[2],	level.world_map.marker_toggle[3],	level.world_map.marker_toggle[4],	level.world_map.marker_toggle[5] );
	self SetShaderConstant( localClientNum, 4, level.world_map.widget_toggle[0],	level.world_map.widget_toggle[1],	level.world_map.widget_toggle[2],	level.world_map.widget_toggle[3] );
	self SetShaderConstant( localClientNum, 5, level.world_map.widget_toggle[4],	level.world_map.widget_toggle[5],	level.world_map.main_icon,			0 );
}

refresh_all_map_shaders( localClientNum )
{
	foreach( map in level.m_map_monitors )
	{
		map refresh_map_shaders( localClientNum );
	}
}

// Setting the flag assigns the shader constants.
// Clearing it updates the values according to what's stored in script.
//
map_monitor_run( localClientNum, set, newEnt )
{
	if ( set )
	{
		if ( !isdefined( self.shader_inited ) )
		{
			self MapShaderConstant( localClientNum, 0, "ScriptVector0" );
			self MapShaderconstant( localClientNum, 1, "ScriptVector1" );
			self MapShaderconstant( localClientNum, 2, "ScriptVector2" );
			self MapShaderconstant( localClientNum, 3, "ScriptVector3" );
			self MapShaderconstant( localClientNum, 4, "ScriptVector4" );
			self MapShaderconstant( localClientNum, 5, "ScriptVector5" );
			
			if ( !isdefined( level.m_map_monitors ) )
				level.m_map_monitors = [];
			
			level.m_map_monitors[level.m_map_monitors.size] = self;
		}
		
		self refresh_map_shaders( localClientNum );
	}
}


set_world_map_tint( index, tint_type_index )
{
	level.world_map.tint[index] = tint_type_index;
}

toggle_world_map_widget( index, toggle_on )
{
	level.world_map.widget_toggle[index] = toggle_on;
}

toggle_world_map_marker( index, toggle_on )
{
	level.world_map.marker_toggle[index] = toggle_on;
}

set_world_map_icon( icon_index )
{
	level.world_map.main_icon = icon_index;
}

set_world_map_translation( x, y )
{
	level.world_map.transform[0] = x;
	level.world_map.transform[1] = y;
}

set_world_map_rotation( theta )
{
	level.world_map.transform[2] = theta;
}

set_world_map_scale( scale )
{
	level.world_map.transform[3] = scale;
}

world_map_translate_to( localClientNum, pos_x, pos_y, map_scale )
{
	start_x = level.world_map.transform[0];
	start_y = level.world_map.transform[1];
	start_scale = level.world_map.transform[3];

	for ( f = 0.0; f <= 1.0; f+=0.1 )
	{
		level.world_map.transform[0] = lerpfloat( start_x, pos_x, f );
		level.world_map.transform[1] = lerpfloat( start_y, pos_y, f );
		level.world_map.transform[3] = lerpfloat( start_scale, map_scale, f );
		refresh_all_map_shaders( localClientNum );
		wait .01;
	}
}

set_speeding_osprey( localClientNum, set, newEnt )
{
	if ( set )
		self.booster_speed_override = 1200.0;
	else
		self.booster_speed_override = undefined;
}

initialize_hologram( localClientNum )
{
	self.shader_inited = true;
	
	self MapShaderConstant( localClientNum, 0, "ScriptVector0" );
	self SetShaderConstant( localclientnum, 0, 1, 1, 1, 1 );
	
	self.color_id = 0;
	
	self MapShaderConstant( localClientNum, 1, "ScriptVector1" );
	self SetShaderConstant( localClientNum, 1, 0, 0, 0, 0 );
}

set_hologram_red( localClientNum, set, newEnt )
{
	if ( !isdefined(self.shader_inited) )
	{
		self initialize_hologram( localClientNum );
	}
	
	if ( set )
	{
		self SetShaderConstant( localClientNum, 1, 1, 0, 0, 0 );
		self.color_id = 1;
	} else {
		self SetShaderConstant( localClientNum, 1, 0, 0, 0, 0 );
		self.color_id = 0;
	}
}

// CLIENT_FLAG_HOLO_VISIBLE
//
set_hologram_shown( localClientNum, set, newEnt)
{
	self endon( "death" );
	
	if ( !isdefined(self.shader_inited) )
	{
		self initialize_hologram( localClientNum );
	}
	
	start_val = 0.2;
	end_val = 1.0;
	
	if ( set )
	{
		start_val = 1.0;
		end_val = 0.2;
	}
	
	for ( f = 0.0; f <= 1.0; f+=0.02 )
	{
		val = lerpfloat( start_val, end_val, f );
		self SetShaderConstant( localClientNum, 1, self.color_id, val, 0, 0 );
		wait 0.01;
	}
	
	if ( set )
		self SetShaderConstant( localClientNum, 1, self.color_id, 0, 0, 0 );
	else
		self SetShaderConstant( localClientNum, 1, self.color_id, 1, 0, 0 );
}

default_settings()
{
	SetClientDvar( "hud_showstance", 0 );
	SetClientDvar( "compass", 0);
}


SetTrackInfoQRCode(index)
{
	setup_qr_code("frontend", 3, index);
}
