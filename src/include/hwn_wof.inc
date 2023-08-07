#if defined _hwn_wof_included
  #endinput
#endif
#define _hwn_wof_included

#pragma reqlib hwn_wof

native Hwn_Wof_Spell_Register(const szName[], const szInvokeCallback[] = "", const szRevokeCallback[] = "");
native Hwn_Wof_Spell_GetCount();
native Hwn_Wof_Spell_GetName(iSpell, szOutput[], iLen);
native Hwn_Wof_Spell_GetHandler(const szName[]);
native Hwn_Wof_Spell_GetDictionaryKey(iSpell, szOutput[], iLen);
native Hwn_Wof_Roll();
native Hwn_Wof_Abort();
native Hwn_Wof_Effect_GetCurrentSpell();
native Float:Hwn_Wof_Effect_GetStartTime();
native Float:Hwn_Wof_Effect_GetDuration();

forward Hwn_Wof_Fw_Roll_Start();
forward Hwn_Wof_Fw_Roll_End();
forward Hwn_Wof_Fw_Effect_Start(iSpell);
forward Hwn_Wof_Fw_Effect_End(iSpell);
forward Hwn_Wof_Fw_Effect_Invoke(pPlayer, iSpell, Float:flEffectTime);
forward Hwn_Wof_Fw_Effect_Revoke(pPlayer, iSpell);
forward Hwn_Wof_Fw_Abort();
