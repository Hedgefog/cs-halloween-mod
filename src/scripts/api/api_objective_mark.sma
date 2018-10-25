#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>

#define MAX_DISTANCE 1024.0
#define MIN_DISTANCE 128.0
#define MIN_SCALE 0.05

#define MARK_CLASSNAME "obj_mark"

new g_ptrEnvSprite;

new g_sprTestMarkAttack;
new g_sprTestMarkDefend;

enum FramePoint
{
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight
}

//new Float:OriginOffsets[OriginOffset] =  {_:13.0,_:25.0,_:36.0};

new Float:ScaleMultiplier = 0.05;
new Float:ScaleLower = 0.005

public plugin_init() {
    register_plugin("[API] Objective Mark", "Hedgehog Fog", "0.0.1");

    g_ptrEnvSprite = engfunc(EngFunc_AllocString , "env_sprite");

    register_forward(FM_AddToFullPack, "On_AddToFullPack", 1);

    register_clcmd("mark_attack", "On_ClCmdSayMarkAttack");
    register_clcmd("mark_defend", "On_ClCmdSayMarkDefend");
}

public plugin_precache() {
    g_sprTestMarkAttack = precache_model("sprites/hwn/home_blue.spr");
    g_sprTestMarkDefend = precache_model("sprites/hwn/home_red.spr");
}

public On_AddToFullPack(es, e, ent, host, hostFlags, player, pSet) {
    if (!is_user_connected(host)) {
        return FMRES_IGNORED;
    }

    if (!ent || !pev_valid(ent)) {
        return FMRES_IGNORED;
    }

    static szClassname[32];
    pev(ent, pev_classname, szClassname, charsmax(szClassname));

    if (!equal(szClassname, MARK_CLASSNAME)) {
        return FMRES_IGNORED;
    }

    new owner = pev(ent, pev_owner);
    new team = pev(ent, pev_team);

    if (owner) {
        if (owner != host) {
            return FMRES_IGNORED;
        }
    } else if (team) {
        // todo: check host team
    }

    DrawMark(ent, host, es);

    return FMRES_IGNORED;
}

#define TEST_MARK_SIZE Float:{64.0, 64.0, 64.0}

public On_ClCmdSayMarkAttack(id) {
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    CreateMark(
        .modelIndex = g_sprTestMarkAttack,
        .fScale = 0.5,
        .vOrigin = vOrigin,
        .vSize = TEST_MARK_SIZE
    );
}

public On_ClCmdSayMarkDefend(id) {
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    CreateMark(
        .modelIndex = g_sprTestMarkDefend,
        .fScale = 0.5,
        .vOrigin = vOrigin,
        .vSize = TEST_MARK_SIZE
    );
}

CreateMark(player = 0, team = 0, modelIndex, Float:fScale, const Float:vOrigin[3], const Float:vSize[3]) {
    new ent = engfunc(EngFunc_CreateNamedEntity, g_ptrEnvSprite);
    set_pev(ent, pev_classname, "obj_mark");
    // set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW);
    set_pev(ent, pev_origin, vOrigin);
    set_pev(ent, pev_scale, fScale);
    set_pev(ent, pev_modelindex, modelIndex);
    set_pev(ent, pev_team, team);
    set_pev(ent, pev_owner, player);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    set_pev(ent, pev_renderamt, 120.0);
    set_pev(ent, pev_movetype, MOVETYPE_NONE);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_vuser1, vSize);

    // dllfunc(DLLFunc_Spawn, ent);

    return ent;
}

DrawMark(ent, host, es) {
    // static Float:fScale;
    // pev(ent, pev_scale, fScale);

    // static Float:vMarkOrigin[3];
    // fScale *= GetMarkOrigin(ent, host, vMarkOrigin);

    // if(fScale < ScaleLower) {
    //     fScale = ScaleLower;
    // }

    // set_es(es, ES_Origin, vMarkOrigin);
    // set_es(es, ES_Scale, fScale);

    // if(engfunc(EngFunc_CheckVisibility, ent, pSet))
    {
        static Float:vPlayerOrigin[3];
        pev(host, pev_origin, vPlayerOrigin);

        static Float:vPlayerVOffset[3];
        pev(host, pev_view_ofs, vPlayerVOffset);

        static Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        static Float:fScale;
        pev(ent, pev_scale, fScale);

        static Float:vSize[3];
        pev(ent, pev_vuser1, vSize);

        static Float:vOffset[3];
        xs_vec_mul_scalar(vSize, fScale, vOffset);

        static Float:vDiff[3];
        xs_vec_sub(vOrigin, vPlayerOrigin, vDiff);
        xs_vec_normalize(vDiff, vDiff);

        static Float:vDiffAngles[3];
        vector_to_angle(vDiff, vDiffAngles);
        vDiffAngles[0] = -vDiffAngles[0];
        
        static Float:framePoints[FramePoint][3];
        CalculateFramePoints(vOrigin, framePoints, vDiffAngles, vOffset);

        static Float:vEyes[3];
        xs_vec_copy(vPlayerOrigin, vEyes);
        xs_vec_add(vEyes, vPlayerVOffset, vEyes);
        
        static Float:framePointsTraced[FramePoint][3];
        static FramePoint:closerFramePoint;
        
        if (TraceEyesFrame(host, vEyes, framePoints, framePointsTraced, closerFramePoint))
        {
            // fScale *= ScaleMultiplier * vector_distance(framePointsTraced[TopLeft], framePointsTraced[TopRight]);
            fScale *= get_distance_f(vEyes, framePointsTraced[closerFramePoint]) / get_distance_f(vEyes, vOrigin);
            if(fScale < ScaleLower) {
                fScale = ScaleLower;
            }

            static Float:vTopBottomVector[3];
            angle_vector(vDiffAngles, ANGLEVECTOR_UP, vTopBottomVector);

            static Float:vSideVector[3];
            angle_vector(vDiffAngles, ANGLEVECTOR_RIGHT, vSideVector);

            static Float:vAnotherPointInThePlane[3];
            xs_vec_mul_scalar(vTopBottomVector, fScale, vAnotherPointInThePlane);
            xs_vec_add(vAnotherPointInThePlane, framePointsTraced[closerFramePoint], vAnotherPointInThePlane);
            
            static Float:vOtherPointInThePlane[3];
            xs_vec_mul_scalar(vSideVector, fScale, vOtherPointInThePlane);
            xs_vec_add(vOtherPointInThePlane, framePointsTraced[closerFramePoint], vOtherPointInThePlane);
            
            static Float:plane[4];
            xs_plane_3p(plane, framePointsTraced[closerFramePoint], vOtherPointInThePlane, vAnotherPointInThePlane);
            MoveToPlane(plane, vEyes, framePointsTraced, closerFramePoint);
            
            static Float:vMiddle[3];
            xs_vec_add(framePointsTraced[TopLeft], framePointsTraced[BottomRight], vMiddle);
            xs_vec_div_scalar(vMiddle, 2.0, vMiddle);

            set_es(es, ES_Scale, fScale);
            set_es(es, ES_Angles, vDiffAngles);
            set_es(es, ES_Origin, vMiddle);
        }
    }

    // set_es(es, ES_Effects, get_es(es, ES_Effects) & ~EF_NODRAW);
}

// joaquimandrade
CalculateFramePoints(Float:origin[3], Float:framePoints[FramePoint][3], const Float:perpendicularAngles[3], const Float:vOffset[3])
{
    static Float:sideVector[3];
    angle_vector(perpendicularAngles, ANGLEVECTOR_RIGHT, sideVector);
    
    static Float:topBottomVector[3];
    angle_vector(perpendicularAngles, ANGLEVECTOR_UP, topBottomVector);
    
    static Float:sideDislocation[3];
    xs_vec_mul_scalar(sideVector, Float:vOffset[0], sideDislocation);
    
    static Float:bottomDislocation[3];
    xs_vec_mul_scalar(topBottomVector, Float:vOffset[1], bottomDislocation);
    
    static Float:topDislocation[3];
    xs_vec_mul_scalar(topBottomVector, Float:vOffset[2], topDislocation);

    xs_vec_copy(topDislocation, framePoints[TopLeft]);
    
    xs_vec_add(framePoints[TopLeft], sideDislocation, framePoints[TopRight]);
    xs_vec_sub(framePoints[TopLeft], sideDislocation, framePoints[TopLeft]);
    
    xs_vec_neg(bottomDislocation, framePoints[BottomLeft]);
    
    xs_vec_add(framePoints[BottomLeft], sideDislocation, framePoints[BottomRight]);
    xs_vec_sub(framePoints[BottomLeft], sideDislocation, framePoints[BottomLeft]);
    
    for(new FramePoint:i = TopLeft; i <= BottomRight; i++) {
        xs_vec_add(origin, framePoints[i], framePoints[i]);
    }
}

// joaquimandrade
bool:TraceEyesFrame(id, const Float:vEyes[3], Float:framePoints[FramePoint][3], Float:framePointsTraced[FramePoint][3], &FramePoint:closerFramePoint)
{
    new Float:fMinFraction = 1.0
    
    for (new FramePoint:i = TopLeft; i <= BottomRight; ++i) {
        new tr;
        engfunc(EngFunc_TraceLine, vEyes, framePoints[i], IGNORE_GLASS, id, tr)
        
        new Float:fFraction;
        get_tr2(tr, TR_flFraction, fFraction);
        
        if (fFraction == 1.0) {
            return false;
        }

        if (fFraction < fMinFraction) {
            fMinFraction = fFraction;
            closerFramePoint = i;
        }

        static Float:vTmp[3];
        {
            xs_vec_sub(vEyes, framePoints[i], vTmp);
            xs_vec_normalize(vTmp, vTmp);
            xs_vec_mul_scalar(vTmp, 8.0, vTmp);
        }
        
        get_tr2(tr, TR_EndPos, framePointsTraced[i]);
        xs_vec_add(framePointsTraced[i], vTmp, framePointsTraced[i]);
    }
    
    return true;
}

// joaquimandrade
MoveToPlane(Float:plane[4], const Float:vEyes[3], Float:framePointsTraced[FramePoint][3], FramePoint:alreadyInPlane)
{
    new Float:vDirection[3];
    for (new FramePoint:i = TopLeft; i < alreadyInPlane; ++i) {
        xs_vec_sub(vEyes, framePointsTraced[i], vDirection);
        xs_plane_rayintersect(plane, framePointsTraced[i], vDirection, framePointsTraced[i]);
    }
    
    for (new FramePoint:i = alreadyInPlane + FramePoint:1; i <= BottomRight; ++i) {
        xs_vec_sub(vEyes, framePointsTraced[i], vDirection);
        xs_plane_rayintersect(plane, framePointsTraced[i], vDirection, framePointsTraced[i]);
    }
}

Float:GetMarkOrigin(mark, player, Float:vOut[3]) {
    static Float:vOrigin[3];
    pev(mark, pev_origin, vOrigin);
    
    static Float:vEyes[3];
    {
        pev(player, pev_origin, vEyes);

        static Float:vPlayerVOffset[3];
        pev(player, pev_view_ofs, vPlayerVOffset);

        xs_vec_add(vEyes, vPlayerVOffset, vEyes);
    }
    
    new tr;
    engfunc(EngFunc_TraceLine, vEyes, vOrigin, IGNORE_GLASS, player, tr)
    
    new Float:fFraction;
    get_tr2(tr, TR_flFraction, fFraction);
    get_tr2(tr, TR_EndPos, vOut);

    if (fFraction < 1.0) {
        static Float:vTmp[3];
        xs_vec_sub(vEyes, vOrigin, vTmp);
        xs_vec_normalize(vTmp, vTmp);
        xs_vec_mul_scalar(vTmp, 8.0, vTmp);
        xs_vec_add(vOut, vTmp, vOut);
    }
    
    return get_distance_f(vEyes, vOut) / get_distance_f(vEyes, vOrigin);
}
