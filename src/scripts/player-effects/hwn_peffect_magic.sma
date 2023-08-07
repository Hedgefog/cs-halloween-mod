#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Magic Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "magic"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke");
}

@Player_EffectInvoke(pPlayer) {
    new iSpellsNum = Hwn_Spell_GetCount();
    if (!iSpellsNum) {
        return;
    }

    new iSpell = Hwn_Spell_GetPlayerSpell(pPlayer);
    if (iSpell >= 0) {
        return;
    }

    Hwn_Spell_SetPlayerSpell(pPlayer, random(iSpellsNum), 1);
}

@Player_EffectRevoke(pPlayer) {}
