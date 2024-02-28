#include <amxmodx>

#include <api_player_effects>

#include <hwn>

#define PLUGIN "[Hwn] Magic Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "hwn-magic"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke");
}

@Player_EffectInvoke(this) {
    new iSpellsNum = Hwn_Spell_GetCount();
    if (!iSpellsNum) return;

    new iSpell = Hwn_Spell_GetPlayerSpell(this);
    if (iSpell >= 0) return;

    Hwn_Spell_SetPlayerSpell(this, random(iSpellsNum), 1);
}

@Player_EffectRevoke(this) {}
