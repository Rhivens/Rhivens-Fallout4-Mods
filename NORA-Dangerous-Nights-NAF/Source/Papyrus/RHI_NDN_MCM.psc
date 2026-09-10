Scriptname RHI_NDN_MCM extends Quest

Actor Property PlayerRef Auto Const Mandatory

GlobalVariable Property RHI_NDN_Enabled Auto Const Mandatory
GlobalVariable Property RHI_NDN_Debug Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChancePlayerSettlement Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceTown Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceDungeon Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceOutdoor Auto Const Mandatory
GlobalVariable Property RHI_NDN_AttackerCount Auto Const Mandatory

String Property MOD_NAME = "RHI_NDN" AutoReadOnly

Event OnQuestInit()
    RegisterEvents()
    UpdateSettings()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    RegisterEvents()
    UpdateSettings()
EndEvent

Function RegisterEvents()
    UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
    RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
    UnregisterForExternalEvent("OnMCMSettingChange|" + MOD_NAME)
    RegisterForExternalEvent("OnMCMSettingChange|" + MOD_NAME, "OnMCMSettingChange")
EndFunction

Function OnMCMSettingChange(String modName, String id)
    If modName == MOD_NAME
        UpdateSettings()
    EndIf
EndFunction

Function UpdateSettings()
    LoadSetting(RHI_NDN_Enabled, "fEnabled:Global", 0.0, 1.0)
    LoadSetting(RHI_NDN_Debug, "fDebug:Global", 0.0, 1.0)
    LoadSetting(RHI_NDN_ChancePlayerSettlement, "fPlayerSettlement:Chances", 0.0, 100.0)
    LoadSetting(RHI_NDN_ChanceTown, "fTown:Chances", 0.0, 100.0)
    LoadSetting(RHI_NDN_ChanceDungeon, "fDungeon:Chances", 0.0, 100.0)
    LoadSetting(RHI_NDN_ChanceOutdoor, "fOutdoor:Chances", 0.0, 100.0)
    LoadSetting(RHI_NDN_AttackerCount, "fAttackerCount:Scene", 0.0, 2.0)
EndFunction

Function LoadSetting(GlobalVariable akGlobal, String asSetting, Float afMinimum, Float afMaximum)
    If !akGlobal
        Debug.Trace("[RHI_NDN] Propriété Global manquante pour " + asSetting)
        Return
    EndIf

    Float value = MCM.GetModSettingFloat(MOD_NAME, asSetting)

    If value < afMinimum
        value = afMinimum
        MCM.SetModSettingFloat(MOD_NAME, asSetting, value)
    ElseIf value > afMaximum
        value = afMaximum
        MCM.SetModSettingFloat(MOD_NAME, asSetting, value)
    EndIf

    If akGlobal.GetValue() != value
        akGlobal.SetValue(value)
    EndIf
EndFunction

Event OnQuestShutdown()
    UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
    UnregisterForExternalEvent("OnMCMSettingChange|" + MOD_NAME)
EndEvent
