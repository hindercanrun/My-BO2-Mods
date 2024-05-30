//
// file: panama_amb.gsc
// description: level ambience script for Panama
// scripter: hindercanrun
//

#include maps\_music;
#include maps\_ambientpackage;

main()
{
	level thread docks_glass_smash();
//	level thread dog_loop();
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////**********  AUDIO THREADS **********/////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

docks_glass_smash()
{
	level endon( "entering_elevator" );

	while ( true )
	{
		level waittill( "glass_smash", pos );

		PlaySoundAtPosition( "dst_docks_window_shatter", pos );
	}
}

dingbat_shot_sound( e_digbat )
{
	level.player Playsound( "evt_dingbat_shot" );
}

sndChangeMotelMusicState( duderino )
{
	SetMusicState( "PANAMA_NORIEGA" );
}
