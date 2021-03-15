// Insurgency's Mosin Nagant (Moist Nugget)
/* Model Credits
/ Model: Seth Soldier (Forgotten Hope 2), Norman The Loli Pirate (Scope ViewModel, Clip, 7.62x54R Bullet)
/ Textures: Seth Soldier (Forgotten Hope 2), Norman The Loli Pirate (Scope ViewModel, Clip, 7.62x54R Bullet)
/ Animations: New World Interactive (Norman The Loli Pirate minor edits), D.N.I.O. 071 (Small edits)
/ Sounds: New World Interactive, D.N.I.O. 071 (Conversion to .ogg format)
/ Sprites: D.N.I.O. 071 (Model Render), R4to0 (Vector), KernCore (.spr Compile)
/ Misc: Norman The Loli Pirate (World Model), D.N.I.O. 071 (World Model UVs, Compile), KernCore (World Model UVs)
/ Script: KernCore
*/

#include "../base"

namespace INS2_MOSIN
{

// Animations
enum INS2_MOSIN_Animations
{
	IDLE = 0,
	IDLE_EMPTY,
	DRAW_FIRST,
	DRAW,
	DRAW_EMPTY,
	HOLSTER,
	HOLSTER_EMPTY,
	FIRE,
	FIRE_LAST,
	DRYFIRE,
	BOLT,
	RELOAD_START,
	RELOAD_START_EMPTY,
	RELOAD_INSERT_FIRST,
	RELOAD_INSERT,
	RELOAD_END,
	RELOAD_END_EMPTY,
	SCOPE_TO,
	SCOPE_TO_EMPTY,
	SCOPE_FROM,
	SCOPE_FROM_EMPTY
};

enum SCOPE_Animations
{
	SCP_IDLE_FOV20 = 0,
	SCP_FIRE_FOV20,
	SCP_FIRELAST_FOV20,
	SCP_DRYFIRE_FOV20
};

// Models
string W_MODEL = "models/ins2/wpn/mosin/w_mosin.mdl";
string V_MODEL = "models/ins2/wpn/mosin/v_mosin.mdl";
string P_MODEL = "models/ins2/wpn/mosin/p_mosin.mdl";
string S_MODEL = "models/ins2/wpn/scopes/mosin.mdl";
string A_MODEL = "models/ins2/ammo/mags.mdl";
int MAG_BDYGRP = 21;
// Sprites
string SPR_CAT = "ins2/srf/"; //Weapon category used to get the sprite's location
// Sounds
string SHOOT_S = "ins2/wpn/mosin/shoot.ogg";
string EMPTY_S = "ins2/wpn/mosin/empty.ogg";
// Information
int MAX_CARRY   	= 1000;
int MAX_CLIP    	= 5;
int DEFAULT_GIVE 	= MAX_CLIP * 4;
int WEIGHT      	= 20;
int FLAGS       	= ITEM_FLAG_NOAUTORELOAD | ITEM_FLAG_NOAUTOSWITCHEMPTY;
uint DAMAGE     	= 110;
uint SLOT       	= 7;
uint POSITION   	= 5;
float RPM       	= 1.65f; //Rounds per minute in air
string AMMO_TYPE 	= "ins2_7.62x54mm";

class weapon_ins2mosin : ScriptBasePlayerWeaponEntity, INS2BASE::WeaponBase
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
	private int m_iShell;
	private bool m_WasDrawn, m_fSniperReload, m_bCanBolt;
	private float m_flNextReload;
	private int GetBodygroup()
	{
		if( self.m_iClip > 0 )
			return 1;

		return 0;
	}
	private array<string> Sounds = {
		"ins2/wpn/mosin/bltbk.ogg",
		"ins2/wpn/mosin/bltfd.ogg",
		"ins2/wpn/mosin/bltlat.ogg",
		"ins2/wpn/mosin/bltrel.ogg",
		"ins2/wpn/mosin/ins.ogg",
		EMPTY_S,
		SHOOT_S
	};

	void Spawn()
	{
		Precache();
		m_WasDrawn = false;
		CommonSpawn( W_MODEL, DEFAULT_GIVE );
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( W_MODEL );
		g_Game.PrecacheModel( V_MODEL );
		g_Game.PrecacheModel( P_MODEL );
		g_Game.PrecacheModel( A_MODEL );
		g_Game.PrecacheModel( S_MODEL );
		m_iShell = g_Game.PrecacheModel( INS2BASE::BULLET_762x54 );

		g_Game.PrecacheOther( GetAmmoName() );

		INS2BASE::PrecacheSound( Sounds );
		INS2BASE::PrecacheSound( INS2BASE::DeployFirearmSounds );
		g_Game.PrecacheGeneric( "sprites/" + SPR_CAT + self.pev.classname + ".txt" );
		CommonPrecache();
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= (INS2BASE::ShouldUseCustomAmmo) ? MAX_CARRY : INS2BASE::DF_MAX_CARRY_M40A1;
		info.iAmmo1Drop	= MAX_CLIP;
		info.iMaxAmmo2 	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip 	= MAX_CLIP;
		info.iSlot  	= SLOT;
		info.iPosition 	= POSITION;
		info.iId     	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags 	= FLAGS;
		info.iWeight 	= WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		return CommonAddToPlayer( pPlayer );
	}

	bool PlayEmptySound()
	{
		return CommonPlayEmptySound( EMPTY_S );
	}

	bool Deploy()
	{
		PlayDeploySound( 3 );
		if( m_WasDrawn == false )
		{
			m_WasDrawn = true;
			return Deploy( V_MODEL, P_MODEL, DRAW_FIRST, "sniper", GetBodygroup(), (89.0/35.0) );
		}
		else
		{
			if( m_bCanBolt )
			{
				SetThink( ThinkFunction( this.BoltBackThink ) );
				self.pev.nextthink = g_Engine.time + (21.0/30.0);
			}

			return Deploy( V_MODEL, P_MODEL, (self.m_iClip <= 0 || m_bCanBolt) ? DRAW_EMPTY : DRAW, "sniper", GetBodygroup(), (22.0/30.0) );
		}
	}

	void BoltBackThink()
	{
		SetThink( null );

		if( self.m_iClip > 0 ) //Checking again in case the player depleted the ammo and didn't let go of the attack button
		{
			self.SendWeaponAnim( BOLT, 0, GetBodygroup() );
			self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = WeaponTimeBase() + (44.0/33.0);
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (52.0/33.0);

			SetThink( ThinkFunction( this.ShellEjectThink ) );
			self.pev.nextthink = WeaponTimeBase() + 0.69;
		}
		m_bCanBolt = false;
	}

	void Holster( int skipLocal = 0 )
	{
		m_fSniperReload = false;
		CommonHolster();

		BaseClass.Holster( skipLocal );
	}

	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			if( WeaponADSMode == INS2BASE::IRON_IN )
				self.SendWeaponAnim( SCP_DRYFIRE_FOV20, 0, GetBodygroup() );
			else
				self.SendWeaponAnim( DRYFIRE, 0, GetBodygroup() );

			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.3f;
			return;
		}

		if( m_pPlayer.m_afButtonPressed & IN_ATTACK == 0 )
			return;

		ShootWeapon( SHOOT_S, 1, VecModAcc( VECTOR_CONE_1DEGREES, 1.25f, 0.25f, 1.25f ), (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD) ? 1024 : 16384, DAMAGE, true, DMG_SNIPER | DMG_NEVERGIB );

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = (self.m_iClip == 0) ? WeaponTimeBase() + 0.27 : WeaponTimeBase() + RPM;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.0f;

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		PunchAngle( Vector( Math.RandomFloat( -6.5, -5.5 ), (Math.RandomLong( 0, 1 ) < 0.5) ? -2.2f : 3.4f, Math.RandomFloat( -0.5, 0.5 ) ) );

		if( self.m_iClip > 0 )
		{
			m_bCanBolt = true;
			SetThink( ThinkFunction( this.ShellEjectThink ) );
			self.pev.nextthink = WeaponTimeBase() + (33.0/33.0);
		}
		else
			SetThink( null );

		if( WeaponADSMode == INS2BASE::IRON_IN )
			self.SendWeaponAnim( (self.m_iClip == 0) ? SCP_FIRELAST_FOV20 : SCP_FIRE_FOV20, 0, GetBodygroup() );
		else
			self.SendWeaponAnim( (self.m_iClip == 0) ? FIRE_LAST : FIRE, 0, GetBodygroup() );
	}

	void ShellEjectThink() //For the think function used in shoot
	{
		m_bCanBolt = false;
		SetThink( null );
		ShellEject( m_pPlayer, m_iShell, (WeaponADSMode != INS2BASE::IRON_IN) ? Vector( 18.5, 6.5, -7.5 ) : Vector( 18.5, 1.6, -3.55 ) );
	}

	void SightThink()
	{
		ToggleZoom( 20 );
		WeaponADSMode = INS2BASE::IRON_IN;
		SetPlayerSpeed();
		m_pPlayer.m_szAnimExtension = "sniperscope";
		m_pPlayer.SetVModelPos( Vector( 0, 0, 0 ) );
		m_pPlayer.pev.viewmodel = S_MODEL;
		self.SendWeaponAnim( SCP_IDLE_FOV20, 0, GetBodygroup() );
	}

	void SecondaryAttack()
	{
		self.m_flTimeWeaponIdle = self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.47;
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.47;
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, INS2BASE::AimDownSights_in[ Math.RandomLong( 0, INS2BASE::AimDownSights_in.length() - 1 )], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

		switch( WeaponADSMode )
		{
			case INS2BASE::IRON_OUT:
			{
				self.SendWeaponAnim( (self.m_iClip > 0) ? SCOPE_TO : SCOPE_TO_EMPTY, 0, GetBodygroup() );
				g_PlayerFuncs.ScreenFade( m_pPlayer, Vector( 0, 0, 0 ), 0.47, 0, 255, FFADE_OUT );
				SetThink( ThinkFunction( SightThink ) );
				self.pev.nextthink = WeaponTimeBase() + 0.46;
				break;
			}
			case INS2BASE::IRON_IN:
			{
				self.SendWeaponAnim( (self.m_iClip > 0) ? SCOPE_FROM : SCOPE_FROM_EMPTY, 0, GetBodygroup() );
				m_pPlayer.ResetVModelPos();
				m_pPlayer.pev.viewmodel = V_MODEL;
				m_pPlayer.m_szAnimExtension = "sniper";
				EffectsFOVOFF();
				break;
			}
		}
	}

	void ItemPreFrame()
	{
		//if( m_pPlayer.m_bitsDamageType & DMG_SHOCK_GLOW != 0 )
		//	m_pPlayer.m_bitsDamageType &= ~DMG_SHOCK_GLOW;

		if( m_reloadTimer < g_Engine.time && canReload )
			self.Reload();

		BaseClass.ItemPreFrame();
	}

	void ItemPostFrame()
	{
		// Checks if the player pressed one of the attack buttons, stops the reload and then attack
		if( m_fSniperReload )
		{
			if( (CheckButton() || (self.m_iClip >= MAX_CLIP && m_pPlayer.pev.button & IN_RELOAD != 0)) && m_flNextReload <= g_Engine.time )
			{
				self.SendWeaponAnim( (self.m_iClip > 0) ? RELOAD_END : RELOAD_END_EMPTY, 0, GetBodygroup() );

				self.m_flTimeWeaponIdle = g_Engine.time + (50.0/35.0);
				self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + (48.0/35.0);
				m_fSniperReload = false;
			}
		}
		BaseClass.ItemPostFrame();
	}

	void ShellReloadEjectThink() //For the think function used in reload
	{
		SetThink( null );
		if( self.m_iClip <= 0 )
			ShellEject( m_pPlayer, m_iShell, Vector( 11, 4, -6.75 ), false, false );
		else
		{
			self.m_iClip -= 1;
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) + 1 );
		}
	}

	void Reload()
	{
		int iAmmo = m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );

		if( iAmmo <= 0 || self.m_iClip == MAX_CLIP )
			return;

		if( WeaponADSMode == INS2BASE::IRON_IN )
		{
			m_pPlayer.m_szAnimExtension = "sniper";
			m_pPlayer.pev.viewmodel = V_MODEL;

			self.SendWeaponAnim( (self.m_iClip > 0) ? SCOPE_FROM : SCOPE_FROM_EMPTY, 0, GetBodygroup() );
			m_reloadTimer = g_Engine.time + 0.46;
			m_pPlayer.m_flNextAttack = 0.46;
			canReload = true;
			EffectsFOVOFF();
		}

		if( m_reloadTimer < g_Engine.time )
		{
			if( m_flNextReload > WeaponTimeBase() )
				return;

			// don't reload until recoil is done
			if( self.m_flNextPrimaryAttack > WeaponTimeBase() && !m_fSniperReload )
			{
				m_fSniperReload = false;
				return;
			}
			if( !m_fSniperReload )
			{
				if( self.m_iClip <= 0 )
				{
					self.SendWeaponAnim( RELOAD_START_EMPTY, 0, GetBodygroup() );
					SetThink( ThinkFunction( ShellReloadEjectThink ) );
					self.pev.nextthink = WeaponTimeBase() + (30.0/35.0);

					m_pPlayer.m_flNextAttack = (43.0/35.0); //Always uses a relative time due to prediction
					self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = WeaponTimeBase() + (43.0/35.0);
				}
				else
				{
					self.SendWeaponAnim( RELOAD_START, 0, (self.m_iClip == 1) ? 0 : GetBodygroup() );
					SetThink( ThinkFunction( ShellReloadEjectThink ) );
					self.pev.nextthink = WeaponTimeBase() + (30.0/35.0);

					m_pPlayer.m_flNextAttack = (43.0/35.0); //Always uses a relative time due to prediction
					self.m_flTimeWeaponIdle = self.m_flNextSecondaryAttack = self.m_flNextPrimaryAttack = WeaponTimeBase() + (43.0/35.0);
				}

				canReload = false;
				m_fSniperReload = true;
				return;
			}
			else if( m_fSniperReload )
			{
				if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
					return;

				if( self.m_iClip == MAX_CLIP )
				{
					m_fSniperReload = false;
					return;
				}

				self.SendWeaponAnim( (self.m_iClip == 0) ? RELOAD_INSERT_FIRST : RELOAD_INSERT, 0, GetBodygroup() );
				m_flNextReload = WeaponTimeBase() + (37.0/38.0);
				self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = WeaponTimeBase() + (37.0/38.0);

				self.m_iClip += 1;
				iAmmo -= 1;
			}
		}

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, iAmmo );
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		if( self.m_flTimeWeaponIdle < g_Engine.time )
		{
			if( self.m_iClip == 0 && !m_fSniperReload && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) != 0 )
			{
				//self.Reload();
			}
			else if( m_fSniperReload )
			{
				if( self.m_iClip != MAX_CLIP && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
				{
					self.Reload();
				}
				else
				{
					// reload debounce has timed out
					self.SendWeaponAnim( (self.m_iClip > 0) ? RELOAD_END : RELOAD_END_EMPTY, 0, GetBodygroup() );

					m_fSniperReload = false;
					self.m_flTimeWeaponIdle = g_Engine.time + (50.0/35.0);
					self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + (48.0/35.0);
				}
			}
			else
			{
				if( WeaponADSMode == INS2BASE::IRON_IN )
					self.SendWeaponAnim( SCP_IDLE_FOV20, 0, GetBodygroup() );
				else
					self.SendWeaponAnim( (self.m_iClip > 0) ? IDLE : IDLE_EMPTY, 0, GetBodygroup() );

				self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
			}
		}
	}
}

class MOSIN_MAG : ScriptBasePlayerAmmoEntity, INS2BASE::AmmoBase
{
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, A_MODEL );
		self.pev.body = MAG_BDYGRP;
		BaseClass.Spawn();
	}

	void Precache()
	{
		g_Game.PrecacheModel( A_MODEL );
		CommonPrecache();
	}

	bool AddAmmo( CBaseEntity@ pOther )
	{
		return CommonAddAmmo( pOther, MAX_CLIP, (INS2BASE::ShouldUseCustomAmmo) ? MAX_CARRY : INS2BASE::DF_MAX_CARRY_M40A1, (INS2BASE::ShouldUseCustomAmmo) ? AMMO_TYPE : INS2BASE::DF_AMMO_M40A1 );
	}
}

string GetAmmoName()
{
	return "ammo_ins2mosin";
}

string GetName()
{
	return "weapon_ins2mosin";
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "INS2_MOSIN::weapon_ins2mosin", GetName() ); // Register the weapon entity
	g_CustomEntityFuncs.RegisterCustomEntity( "INS2_MOSIN::MOSIN_MAG", GetAmmoName() ); // Register the ammo entity
	g_ItemRegistry.RegisterWeapon( GetName(), SPR_CAT, (INS2BASE::ShouldUseCustomAmmo) ? AMMO_TYPE : INS2BASE::DF_AMMO_M40A1, "", GetAmmoName() ); // Register the weapon
}

}