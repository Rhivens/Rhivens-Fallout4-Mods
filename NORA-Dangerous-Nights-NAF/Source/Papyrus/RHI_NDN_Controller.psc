Scriptname RHI_NDN_Controller extends Quest
; Version 0.18 RC1: load the Pervert narrative messages from
; RHI_NDN_messages.ini, with the validated English text retained as fallback.

Actor Property PlayerRef Auto Const Mandatory
WorkshopParentScript Property WorkshopParent Auto Const Mandatory

GlobalVariable Property RHI_NDN_Enabled Auto Const Mandatory
GlobalVariable Property RHI_NDN_Debug Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChancePlayerSettlement Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceTown Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceDungeon Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceOutdoor Auto Const Mandatory
GlobalVariable Property RHI_NDN_MaxAttackers Auto Const Mandatory
GlobalVariable Property RHI_NDN_PervertChance Auto Const Mandatory

Keyword Property LocTypeWorkshopSettlement Auto Const Mandatory
Keyword Property LocTypeSettlement Auto Const Mandatory
Keyword Property LocTypeDungeon Auto Const Mandatory
Keyword Property LocTypeDungeonGlowingSea Auto Const Mandatory
ActorValue Property UnarmedDamageAV Auto Const Mandatory

Float Property AttackerUnarmedDamageBonus = 100.0 Auto Const

FormList Property RHI_NDN_AttackerPool Auto Const Mandatory
ReferenceAlias Property AttackerAlias Auto Const Mandatory
Scene Property RHI_NDN_AttackerDialogueScene Auto Const Mandatory

Int Property STATE_IDLE = 0 AutoReadOnly
Int Property STATE_SLEEPING = 10 AutoReadOnly
Int Property STATE_EVALUATING = 20 AutoReadOnly
Int Property STATE_ENCOUNTER = 30 AutoReadOnly

Int CurrentState = 0
Float SleepStartTime = 0.0
Float DesiredWakeTime = 0.0
ObjectReference LastBed = None

Int Property TIMER_WAKEUP = 100 AutoReadOnly
Int Property TIMER_DIAGNOSTIC_CLEANUP = 110 AutoReadOnly
Int Property TIMER_DEATH_CLEANUP = 120 AutoReadOnly
Int Property TIMER_SCENE_MONITOR = 130 AutoReadOnly
Int Property TIMER_COMBAT_MONITOR = 140 AutoReadOnly
Int Property TIMER_VIOLATE_CLEANUP = 150 AutoReadOnly
Int Property TIMER_SUBMIT_FAIL_CLEANUP = 160 AutoReadOnly
Int Property TIMER_SUBMIT_END_CLEANUP = 170 AutoReadOnly
Int Property TIMER_DIALOGUE_APPROACH_TIMEOUT = 180 AutoReadOnly
Int Property TIMER_SUBMIT_DEPARTURE = 190 AutoReadOnly
Int Property TIMER_SUBMIT_DEFERRED_DELETE = 200 AutoReadOnly
Float Property COMBAT_DESPAWN_DISTANCE = 4096.0 AutoReadOnly
Float Property SUBMIT_SCENE_DURATION = 60.0 Auto Const
Float Property DIALOGUE_START_DISTANCE = 220.0 AutoReadOnly
Float Property DIALOGUE_RECOVERY_DISTANCE = 140.0 AutoReadOnly
Float Property DIALOGUE_APPROACH_TIMEOUT = 8.0 AutoReadOnly
Float Property SUBMIT_DEPARTURE_GRACE = 3.0 AutoReadOnly
Float Property SUBMIT_CLEANUP_GRACE = 25.0 AutoReadOnly
Float Property SUBMIT_FORCED_STOP_GRACE = 5.0 AutoReadOnly
Float Property SUBMIT_DEFERRED_DELETE_RETRY = 15.0 AutoReadOnly
Int Property SUBMIT_DELETE_CLEAR_PASSES_REQUIRED = 2 AutoReadOnly
Int Property MAX_SUPPORTED_ATTACKERS = 3 AutoReadOnly
String Property SUBMIT_SCENE_META = "RHI_NDN_SUBMIT" AutoReadOnly

Actor SpawnedDiagnosticAttacker = None
Actor[] SpawnedEncounterAttackers
Actor[] DeferredSubmissionAttackers
Int DeferredSubmissionClearPasses = 0
InputEnableLayer DialogueInputLayer = None
Bool DialogueMenuWasOpened = false
Int DialogueMonitorTicks = 0
Bool ResistanceCombatActive = false
FPV_OnHit ViolatePlayerScript = None
AAF:AAF_API NAF_API = None
Bool SubmissionSceneActive = false
Bool SubmissionCleanupPending = false
Bool SubmissionResidualStopIssued = false
Bool DialogueApproachActive = false
Bool DialogueCameraActive = false

Event OnQuestInit()
    Trace("Controller initialising")
    RegisterForPlayerSleep()
    CurrentState = STATE_IDLE
    Notify("Controller initialized")
EndEvent

Event OnPlayerSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime, ObjectReference akBed)
    If RHI_NDN_Enabled.GetValue() == 0.0
        Return
    EndIf

    If CurrentState != STATE_IDLE
        Trace("Sleep ignored: controller unavailable, state=" + CurrentState)
        Return
    EndIf

    If PlayerRef.IsInCombat()
        Trace("Sleep ignored: player is in combat")
        Return
    EndIf

    SleepStartTime = afSleepStartTime
    DesiredWakeTime = afDesiredSleepEndTime
    LastBed = akBed
    CurrentState = STATE_SLEEPING
    Trace("Sleep started")
EndEvent

Event OnPlayerSleepStop(Bool abInterrupted, ObjectReference akBed)
    If CurrentState != STATE_SLEEPING
        Return
    EndIf

    If abInterrupted
        Trace("Sleep interrupted: aborted")
        ResetToIdle()
        Return
    EndIf

    CurrentState = STATE_EVALUATING
    CancelTimer(TIMER_WAKEUP)
    StartTimer(3.0, TIMER_WAKEUP)
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    If DeferredSubmissionAttackers == None || DeferredSubmissionAttackers.Length <= 0
        UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
        Return
    EndIf

    ; NAF Bridge also performs load-time scene recovery. Give it priority,
    ; then restart our independent two-pass deletion check.
    DeferredSubmissionClearPasses = 0
    CancelTimer(TIMER_SUBMIT_DEFERRED_DELETE)
    StartTimer(SUBMIT_DEFERRED_DELETE_RETRY, TIMER_SUBMIT_DEFERRED_DELETE)
    Trace("Player load detected; deferred Submit deletion check rearmed")
EndEvent

Event OnTimer(Int aiTimerID)
    If aiTimerID == TIMER_WAKEUP
        EvaluateWakeup()
    ElseIf aiTimerID == TIMER_DIAGNOSTIC_CLEANUP
        CleanupDiagnosticAttacker()
    ElseIf aiTimerID == TIMER_DEATH_CLEANUP
        CleanupDiagnosticAttacker(false)
    ElseIf aiTimerID == TIMER_SCENE_MONITOR
        MonitorDialogueScene()
    ElseIf aiTimerID == TIMER_COMBAT_MONITOR
        MonitorResistanceCombat()
    ElseIf aiTimerID == TIMER_VIOLATE_CLEANUP
        Trace("AAF Violate released the actors; cleaning up the Resist attacker")
        CleanupDiagnosticAttacker(false)
    ElseIf aiTimerID == TIMER_SUBMIT_FAIL_CLEANUP
        Trace("Submit scene did not start; running safety cleanup")
        CleanupDiagnosticAttacker(false)
    ElseIf aiTimerID == TIMER_SUBMIT_END_CLEANUP
        FinalizeSubmissionCleanup()
    ElseIf aiTimerID == TIMER_SUBMIT_DEPARTURE
        BeginSubmissionDeparture()
    ElseIf aiTimerID == TIMER_DIALOGUE_APPROACH_TIMEOUT
        If DialogueApproachActive
            Trace("Approach timed out; applying safety repositioning")
            RecoverDialoguePosition()
        EndIf
    ElseIf aiTimerID == TIMER_SUBMIT_DEFERRED_DELETE
        TryDeleteDeferredSubmissionAttackers()
    EndIf
EndEvent

Event Actor.OnDeath(Actor akSender, Actor akKiller)
    If !IsTrackedEncounterAttacker(akSender)
        Return
    EndIf

    Bool leaderDied = akSender == SpawnedDiagnosticAttacker
    Trace("Encounter actor died; leader=" + leaderDied + " | killer=" + akKiller)

    If AttackerAlias && AttackerAlias.GetReference() == akSender
        AttackerAlias.Clear()
    EndIf

    If leaderDied
        CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
        StopOwnedDialogueCamera("encounter leader died")

        If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
            RHI_NDN_AttackerDialogueScene.Stop()
            Trace("Dialogue scene stopped after encounter leader death")
        EndIf
    EndIf

    ; A death occurring while NAF still owns the actors must never start our
    ; deletion path. OnSceneEnd and its deferred cleanup remain authoritative.
    If SubmissionSceneActive || SubmissionCleanupPending
        Trace("Encounter death deferred to the active Submit cleanup path")
        Return
    EndIf

    If ResistanceCombatActive
        If GetLivingEncounterAttackerCount() <= 0
            CancelTimer(TIMER_COMBAT_MONITOR)
            CancelTimer(TIMER_DEATH_CLEANUP)
            StartTimer(2.0, TIMER_DEATH_CLEANUP)
            Trace("All Resist attackers are dead; deferred cleanup scheduled")
        Else
            StartTimer(1.0, TIMER_COMBAT_MONITOR)
        EndIf
    ElseIf leaderDied
        ; Without the dialogue leader the encounter cannot continue. Keep the
        ; remaining group references valid until the shared safe cleanup runs.
        CancelTimer(TIMER_DEATH_CLEANUP)
        StartTimer(2.0, TIMER_DEATH_CLEANUP)
    EndIf
EndEvent

Function EvaluateWakeup()
    If RHI_NDN_Enabled.GetValue() == 0.0
        ResetToIdle()
        Return
    EndIf

    If PlayerRef.IsInCombat()
        Trace("Wake-up event cancelled: player is in combat")
        ResetToIdle()
        Return
    EndIf

    Trace("Wake-up detected")

    ; Pervert is evaluated first and independently from NDN's location chances.
    ; This lets users set every NDN chance to zero and test only the integration.
    ; If Pervert is missing, unavailable, or rejects the request, normal NDN
    ; evaluation continues without spawning anything on Pervert's behalf.
    If TryStartPervertAbduction()
        ResetToIdle()
        Return
    EndIf

    Location currentLocation = PlayerRef.GetCurrentLocation()
    Int locationType = GetLocationType(currentLocation)
    Float configuredChance = GetChanceForLocationType(locationType)
    Int roll = Utility.RandomInt(1, 100)
    Bool rollSucceeded = roll <= configuredChance

    Trace("Location type: " + GetLocationTypeName(locationType))
    Trace("Roll: " + roll + " / chance: " + configuredChance)

    If rollSucceeded
        Trace("Result: success")
        Notify("Wake-up: " + GetLocationTypeName(locationType) + " | SUCCESS " + roll + "/" + configuredChance)
        SpawnDiagnosticAttacker()
    Else
        Trace("Result: failure")
        Notify("Wake-up: " + GetLocationTypeName(locationType) + " | FAILURE " + roll + "/" + configuredChance)
    EndIf

    ; An active encounter keeps STATE_ENCOUNTER until cleanup completes.
    If !SpawnedDiagnosticAttacker
        ResetToIdle()
    EndIf
EndFunction

Bool Function TryStartPervertAbduction()
    Int configuredChance = RHI_NDN_PervertChance.GetValueInt()

    If configuredChance <= 0
        Return false
    ElseIf configuredChance > 100
        configuredChance = 100
    EndIf

    Int roll = Utility.RandomInt(1, 100)
    Trace("Pervert roll: " + roll + " / chance: " + configuredChance)

    If roll > configuredChance
        Trace("Pervert result: failure; continuing with normal NDN evaluation")
        Return false
    EndIf

    Quest pervertMainQuest = Game.GetFormFromFile(0x00000800, "pervert.esp") as Quest
    If !pervertMainQuest
        Trace("Pervert integration unavailable: pervert.esp or its main quest was not found")
        Notify("Pervert integration unavailable; continuing with normal NDN evaluation")
        Return false
    EndIf

    ScriptObject pervertAPI = pervertMainQuest.CastAs("AAM:AAM_Main")
    If !pervertAPI
        Trace("Pervert integration unavailable: AAM:AAM_Main API was not found")
        Notify("Pervert API unavailable; continuing with normal NDN evaluation")
        Return false
    EndIf

    ; Pervert's own source uses None for akActor in one official fragment.
    ; With no scenario marker supplied, Pervert selects the dungeon associated
    ; with the player's current supported location and owns all further actors,
    ; scenes, transport, and cleanup.
    String fallbackBeforeStart = "While you sleep, a shadow silently approaches your bed. A sharp sting pierces your skin, followed by a strange warmth spreading through your body. Your thoughts dissolve into a drugged haze as someone carries you away..."
    String fallbackOnArrival = "Awareness returns in broken fragments. You are somewhere unfamiliar, unable to focus or think clearly. Shapes move around you through the fog while your body feels distant and unresponsive..."
    String fallbackAfterReturn = "You awaken near your bed, dazed and barely able to think. Your vision swims and your memories are shattered. "
    fallbackAfterReturn = fallbackAfterReturn + "Your aching body and the traces left on your skin make the truth impossible to deny: someone violated you while you were unconscious."

    String beforeStartMessage = GetPervertNarrativeMessage("BeforeStart", fallbackBeforeStart)
    String onArrivalMessage = GetPervertNarrativeMessage("OnArrival", fallbackOnArrival)
    String afterReturnMessage = GetPervertNarrativeMessage("AfterReturn", fallbackAfterReturn)

    Var[] args = new Var[7]
    args[0] = None
    args[1] = true
    args[2] = None
    args[3] = None
    args[4] = beforeStartMessage
    args[5] = onArrivalMessage
    args[6] = afterReturnMessage

    If pervertAPI.CallFunction("startCustomAbduction", args)
        Trace("Pervert abduction request accepted")
        Notify("Wake-up event transferred to Pervert")
        Return true
    EndIf

    Trace("Pervert abduction request rejected; continuing with normal NDN evaluation")
    Notify("Pervert request rejected; continuing with normal NDN evaluation")
    Return false
EndFunction

String Function GetPervertNarrativeMessage(String asKey, String asFallback)
    String configuredMessage = LL_FourPlay.GetCustomConfigOption("RHI_NDN_messages.ini", "Pervert", asKey)

    If configuredMessage == ""
        Trace("Pervert narrative key missing or empty: " + asKey + "; using the built-in English fallback")
        Return asFallback
    EndIf

    Trace("Pervert narrative loaded from RHI_NDN_messages.ini: " + asKey)
    Return configuredMessage
EndFunction

Function StartSubmissionScene()
    Actor leader = SpawnedDiagnosticAttacker

    If !leader || leader.IsDead()
        Trace("Submit cancelled: no valid encounter leader")
        UnlockPlayerMovement()
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)
    CancelTimer(TIMER_COMBAT_MONITOR)

    StopOwnedDialogueCamera("Submit selected")

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Dialogue scene stopped before Submit")
    EndIf

    UnlockPlayerMovement()

    Actor[] submitActors = new Actor[0]
    submitActors.Add(PlayerRef)

    Int attackerIndex = 0
    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        Actor attacker = SpawnedEncounterAttackers[attackerIndex]

        If attacker && !attacker.IsDead()
            attacker.ClearLookAt()
            attacker.StopCombat()
            attacker.StopCombatAlarm()
            attacker.SetRelationshipRank(PlayerRef, 0)
            attacker.EvaluatePackage()
            submitActors.Add(attacker)
        EndIf

        attackerIndex += 1
    EndWhile

    If submitActors.Length == 1 && leader && !leader.IsDead()
        leader.ClearLookAt()
        leader.StopCombat()
        leader.StopCombatAlarm()
        leader.SetRelationshipRank(PlayerRef, 0)
        leader.EvaluatePackage()
        submitActors.Add(leader)
    EndIf

    If submitActors.Length < 2
        Trace("Submit cancelled: no living encounter actors")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    NAF_API = AAF:AAF_API.GetAPI()
    If !NAF_API
        Trace("Submit unavailable: AAF/NAF Bridge API not found")
        Notify("ERROR: NAF Bridge not found")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    RegisterForCustomEvent(NAF_API, "OnSceneInit")
    RegisterForCustomEvent(NAF_API, "OnSceneEnd")
    ; Keep a load-time recovery hook while temporary Submit actors may still
    ; be referenced by NAF's serialized scene and morph-cleanup state.
    UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
    RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")

    AAF:AAF_API:SceneSettings submitSettings = NAF_API.GetSceneSettings()
    submitSettings.duration = SUBMIT_SCENE_DURATION
    submitSettings.preventFurniture = true
    submitSettings.skipWalk = true
    submitSettings.isNPCControlled = true
    submitSettings.ignoreCombat = true
    submitSettings.includeTags = "Aggressive"
    submitSettings.meta = SUBMIT_SCENE_META

    SubmissionSceneActive = true
    SubmissionCleanupPending = false
    SubmissionResidualStopIssued = false
    ; Arm the safeguard before StartScene because NAF may send OnSceneInit
    ; almost immediately.
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    StartTimer(20.0, TIMER_SUBMIT_FAIL_CLEANUP)
    ; Some AAF-compatible API versions declare StartScene without
    ; return value. OnSceneInit and the safety timer provide the result instead.
    NAF_API.StartScene(submitActors, submitSettings)
    Trace("Submit sent to NAF Bridge with " + submitActors.Length + " total actors")
    Notify("Submit: NAF scene requested with " + (submitActors.Length - 1) + " attacker(s)")
EndFunction

Event AAF:AAF_API.OnSceneInit(AAF:AAF_API akSender, Var[] akArgs)
    If !SubmissionSceneActive || akArgs.Length < 1
        Return
    EndIf

    Int status = akArgs[0] as Int
    String sceneMeta = ""

    If status == 0 && akArgs.Length > 5
        sceneMeta = akArgs[5] as String
    ElseIf status != 0 && akArgs.Length > 3
        sceneMeta = akArgs[3] as String
    EndIf

    If sceneMeta != SUBMIT_SCENE_META
        Return
    EndIf

    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)

    If status == 0
        Trace("Submit scene started by NAF")
    Else
        String failureReason = "unknown reason"
        If akArgs.Length > 1
            failureReason = akArgs[1] as String
        EndIf
        Trace("Submit scene failed: " + failureReason)
        Notify("NAF ERROR: " + failureReason)
        StartTimer(1.0, TIMER_SUBMIT_FAIL_CLEANUP)
    EndIf
EndEvent

Event AAF:AAF_API.OnSceneEnd(AAF:AAF_API akSender, Var[] akArgs)
    If !SubmissionSceneActive || akArgs.Length <= 4
        Return
    EndIf

    String sceneMeta = akArgs[4] as String
    If sceneMeta != SUBMIT_SCENE_META
        Return
    EndIf

    SubmissionSceneActive = false
    SubmissionCleanupPending = true
    SubmissionResidualStopIssued = false
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    CancelTimer(TIMER_SUBMIT_END_CLEANUP)
    CancelTimer(TIMER_SUBMIT_DEPARTURE)

    ; NAF Bridge sends OnSceneEnd before equipment, keywords, unload-event
    ; registrations and actor morphs have all been restored. Do not touch the
    ; actor during that callback; begin its departure on a separate timer.
    StartTimer(SUBMIT_DEPARTURE_GRACE, TIMER_SUBMIT_DEPARTURE)
    Trace("Submit scene ended; deferred NAF-safe cleanup scheduled")
EndEvent

Function BeginSubmissionDeparture()
    If !SubmissionCleanupPending
        Trace("Submit departure ignored: no cleanup is pending")
        Return
    EndIf

    If GetTrackedEncounterAttackerCount() <= 0
        Trace("Submit departure found no tracked encounter actors")
        SubmissionCleanupPending = false
        SubmissionResidualStopIssued = false
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    ; NAF Bridge has had its own cleanup window. Release the encounter-specific
    ; behaviour now so each actor can resume its normal package before deletion.
    Int attackerIndex = 0
    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        Actor attacker = SpawnedEncounterAttackers[attackerIndex]

        If attacker && !attacker.IsDead()
            attacker.ClearLookAt()
            attacker.StopCombat()
            attacker.StopCombatAlarm()
            attacker.SetRelationshipRank(PlayerRef, 0)
            attacker.EvaluatePackage()
        EndIf

        attackerIndex += 1
    EndWhile

    If SpawnedDiagnosticAttacker && (SpawnedEncounterAttackers == None || SpawnedEncounterAttackers.Find(SpawnedDiagnosticAttacker) < 0)
        SpawnedDiagnosticAttacker.ClearLookAt()
        SpawnedDiagnosticAttacker.StopCombat()
        SpawnedDiagnosticAttacker.StopCombatAlarm()
        SpawnedDiagnosticAttacker.SetRelationshipRank(PlayerRef, 0)
        SpawnedDiagnosticAttacker.EvaluatePackage()
    EndIf

    CancelTimer(TIMER_SUBMIT_END_CLEANUP)
    StartTimer(SUBMIT_CLEANUP_GRACE, TIMER_SUBMIT_END_CLEANUP)
    Trace("Encounter group released; final cleanup scheduled")
EndFunction

Function FinalizeSubmissionCleanup()
    If !SubmissionCleanupPending
        Trace("Deferred Submit cleanup ignored: no cleanup is pending")
        Return
    EndIf

    If GetTrackedEncounterAttackerCount() <= 0
        Trace("Deferred Submit cleanup found no tracked encounter actors")
        SubmissionCleanupPending = false
        SubmissionResidualStopIssued = false
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    ; Check our temporary actors rather than PlayerRef. This guarantees
    ; that an unrelated scene started by another mod cannot be interrupted.
    If !SubmissionResidualStopIssued
        Actor residualActor = FindEncounterActorInRunningNAFScene()
        If residualActor
            SubmissionResidualStopIssued = true
            Trace("Residual NAF scene detected for encounter group; requesting a clean stop")

            If NAF_API && NAF_API.StopScene(residualActor)
                CancelTimer(TIMER_SUBMIT_END_CLEANUP)
                StartTimer(SUBMIT_FORCED_STOP_GRACE, TIMER_SUBMIT_END_CLEANUP)
                Trace("Residual NAF scene stop accepted; final deletion deferred")
                Return
            EndIf

            Trace("Residual NAF scene stop was not accepted; continuing final cleanup")
        EndIf
    EndIf

    SubmissionCleanupPending = false
    SubmissionResidualStopIssued = false
    Trace("NAF cleanup window completed; hiding encounter group before deferred deletion")
    RetireSubmissionActorsForDeferredDelete()
EndFunction

Function SpawnDiagnosticAttacker()
    CleanupDiagnosticAttacker(false)

    Int poolSize = RHI_NDN_AttackerPool.GetSize()

    If poolSize <= 0
        Trace("Attacker pool is empty")
        Notify("ERROR: attacker pool is empty")
        Return
    EndIf

    Int maximumAttackers = RHI_NDN_MaxAttackers.GetValueInt()
    If maximumAttackers > MAX_SUPPORTED_ATTACKERS
        maximumAttackers = MAX_SUPPORTED_ATTACKERS
    EndIf

    If maximumAttackers > poolSize
        maximumAttackers = poolSize
    EndIf

    If maximumAttackers < 1
        maximumAttackers = 1
    EndIf

    Int desiredAttackerCount = Utility.RandomInt(1, maximumAttackers)
    Int[] availablePoolIndices = new Int[0]
    SpawnedEncounterAttackers = new Actor[0]

    Int poolIndex = 0
    While poolIndex < poolSize
        availablePoolIndices.Add(poolIndex)
        poolIndex += 1
    EndWhile

    While SpawnedEncounterAttackers.Length < desiredAttackerCount && availablePoolIndices.Length > 0
        Int candidateIndex = Utility.RandomInt(0, availablePoolIndices.Length - 1)
        Int selectedIndex = availablePoolIndices[candidateIndex]
        availablePoolIndices.Remove(candidateIndex)
        ActorBase selectedActorBase = RHI_NDN_AttackerPool.GetAt(selectedIndex) as ActorBase

        If selectedActorBase
            ObjectReference spawnedReference = PlayerRef.PlaceAtMe(selectedActorBase, 1, false, false, false)
            Actor spawnedActor = spawnedReference as Actor

            If spawnedActor
                Int groupIndex = SpawnedEncounterAttackers.Length
                SpawnedEncounterAttackers.Add(spawnedActor)

                spawnedActor.ModValue(UnarmedDamageAV, AttackerUnarmedDamageBonus)
                spawnedActor.StopCombat()
                spawnedActor.StopCombatAlarm()
                spawnedActor.SetRelationshipRank(PlayerRef, 0)
                RegisterForRemoteEvent(spawnedActor, "OnDeath")
                PositionEncounterAttacker(spawnedActor, groupIndex)

                Trace("Encounter actor spawned from pool index " + selectedIndex + " as group member " + groupIndex)
            Else
                Trace("Failed to spawn ActorBase from pool index " + selectedIndex)
            EndIf
        Else
            Trace("Invalid ActorBase in attacker pool at index " + selectedIndex)
        EndIf
    EndWhile

    If SpawnedEncounterAttackers.Length <= 0
        Trace("Encounter cancelled: no attackers could be spawned")
        Notify("ERROR: unable to spawn encounter actors")
        SpawnedEncounterAttackers = None
        ResetToIdle()
        Return
    EndIf

    SpawnedDiagnosticAttacker = SpawnedEncounterAttackers[0]
    CurrentState = STATE_ENCOUNTER

    AttackerAlias.ForceRefTo(SpawnedDiagnosticAttacker)

    ; Arm the safeguard before any latent approach. Even if the NPC becomes
    ; stuck or another Papyrus stack takes over, the encounter already has
    ; its global safety timeout.
    Trace("Encounter group ready: requested=" + desiredAttackerCount + " | spawned=" + SpawnedEncounterAttackers.Length)
    Notify(SpawnedEncounterAttackers.Length + " attacker(s) spawned for 60 seconds maximum")
    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    StartTimer(60.0, TIMER_DIAGNOSTIC_CLEANUP)

    If AttackerAlias.GetReference() == SpawnedDiagnosticAttacker
        Trace("Attacker alias assigned to encounter leader")
        Notify("Encounter leader assigned")

        ; Start the Player Dialogue scene only when the leader is close and both
        ; actors are facing each other. Eleanor remains free during the approach.
        BeginDialogueApproach()
    Else
        Trace("Failed to assign attacker alias to encounter leader")
        Notify("ERROR: encounter leader alias not assigned")
        CleanupDiagnosticAttacker(false)
    EndIf

EndFunction

Function PositionEncounterAttacker(Actor akAttacker, Int aiGroupIndex)
    If !akAttacker
        Return
    EndIf

    If aiGroupIndex == 0
        akAttacker.MoveTo(PlayerRef, 100.0, 0.0, 0.0, true)
    ElseIf aiGroupIndex == 1
        akAttacker.MoveTo(PlayerRef, -90.0, 130.0, 0.0, true)
    Else
        akAttacker.MoveTo(PlayerRef, -90.0, -130.0, 0.0, true)
    EndIf

    akAttacker.MoveToNearestNavmeshLocation()
EndFunction

Function BeginDialogueApproach()
    Actor attacker = SpawnedDiagnosticAttacker

    If !attacker || attacker.IsDead()
        Trace("Approach cancelled: no valid attacker")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    Utility.Wait(0.25)

    Float distanceToPlayer = attacker.GetDistance(PlayerRef)
    Trace("Initial distance before dialogue: " + distanceToPlayer)

    If distanceToPlayer <= DIALOGUE_START_DISTANCE
        CompleteDialogueApproach()
        Return
    EndIf

    DialogueApproachActive = true
    CancelTimer(TIMER_DIALOGUE_APPROACH_TIMEOUT)
    StartTimer(DIALOGUE_APPROACH_TIMEOUT, TIMER_DIALOGUE_APPROACH_TIMEOUT)

    Trace("Encounter leader is approaching Eleanor before dialogue")
    Bool reachedPlayer = attacker.PathToReference(PlayerRef, 0.5)

    ; The timer may have interrupted pathing and started recovery on
    ; une autre pile Papyrus. Dans ce cas, cette pile ne doit rien relancer.
    If !DialogueApproachActive || attacker != SpawnedDiagnosticAttacker
        Return
    EndIf

    CancelTimer(TIMER_DIALOGUE_APPROACH_TIMEOUT)
    distanceToPlayer = attacker.GetDistance(PlayerRef)
    Trace("Approach completed: result=" + reachedPlayer + " | distance=" + distanceToPlayer)

    If distanceToPlayer <= DIALOGUE_START_DISTANCE
        CompleteDialogueApproach()
    Else
        RecoverDialoguePosition()
    EndIf
EndFunction

Function RecoverDialoguePosition()
    Actor attacker = SpawnedDiagnosticAttacker

    ; Invalidating the approach immediately prevents the PathToReference stack
    ; from starting the dialogue a second time when it resumes.
    DialogueApproachActive = false
    CancelTimer(TIMER_DIALOGUE_APPROACH_TIMEOUT)

    If !attacker || attacker.IsDead()
        Trace("Recovery cancelled: no valid attacker")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    Float playerAngle = PlayerRef.GetAngleZ()
    Float targetX = PlayerRef.GetPositionX() + (DIALOGUE_RECOVERY_DISTANCE * Math.Sin(playerAngle))
    Float targetY = PlayerRef.GetPositionY() + (DIALOGUE_RECOVERY_DISTANCE * Math.Cos(playerAngle))
    Float targetZ = PlayerRef.GetPositionZ()

    attacker.MoveTo(PlayerRef, 0.0, 0.0, 0.0, true)
    attacker.SetPosition(targetX, targetY, targetZ)
    attacker.MoveToNearestNavmeshLocation()
    Utility.Wait(0.25)

    Float recoveredDistance = attacker.GetDistance(PlayerRef)
    Trace("Distance after safety repositioning: " + recoveredDistance)

    ; If the navmesh pushed the leader too far away, make one final attempt
    ; very close to the player before giving up.
    If recoveredDistance > DIALOGUE_START_DISTANCE
        attacker.MoveTo(PlayerRef, 90.0, 0.0, 0.0, true)
        attacker.MoveToNearestNavmeshLocation()
        Utility.Wait(0.25)
        recoveredDistance = attacker.GetDistance(PlayerRef)
        Trace("Distance after second attempt: " + recoveredDistance)
    EndIf

    If recoveredDistance > DIALOGUE_START_DISTANCE
        Trace("Unable to place the encounter leader within dialogue range; encounter cancelled")
        Notify("ERROR: unable to place the NPC for dialogue")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    CompleteDialogueApproach()
EndFunction

Function CompleteDialogueApproach()
    Actor attacker = SpawnedDiagnosticAttacker

    DialogueApproachActive = false
    CancelTimer(TIMER_DIALOGUE_APPROACH_TIMEOUT)

    If !attacker || attacker.IsDead() || AttackerAlias.GetReference() != attacker
        Trace("Dialogue cancelled: invalid leader or alias after approach")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    Float finalDistance = attacker.GetDistance(PlayerRef)
    If finalDistance > DIALOGUE_START_DISTANCE
        Trace("Dialogue cancelled: leader is still too far away, distance=" + finalDistance)
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    ; Turning Eleanor toward the leader prevents DialogueMenu from waiting for
    ; a manual camera rotation. The leader also faces Eleanor.
    Float playerFacing = PlayerRef.GetAngleZ() + PlayerRef.GetHeadingAngle(attacker)
    Float attackerFacing = attacker.GetAngleZ() + attacker.GetHeadingAngle(PlayerRef)
    PlayerRef.SetAngle(PlayerRef.GetAngleX(), PlayerRef.GetAngleY(), playerFacing)
    attacker.SetAngle(attacker.GetAngleX(), attacker.GetAngleY(), attackerFacing)
    attacker.SetLookAt(PlayerRef, true)
    Utility.Wait(0.25)

    If attacker != SpawnedDiagnosticAttacker
        Return
    EndIf

    LockPlayerMovement()
    RHI_NDN_AttackerDialogueScene.Start()
    ; The player's camera is independent from PlayerRef.SetAngle(). Ask the
    ; dialogue system to center it on the leader so the choices can open even
    ; when the player was looking elsewhere before the encounter.
    Game.StartDialogueCameraOrCenterOnTarget(attacker)
    DialogueCameraActive = true
    Trace("Dialogue camera started and assigned to encounter")
    CancelTimer(TIMER_SCENE_MONITOR)
    StartTimer(0.5, TIMER_SCENE_MONITOR)
    Trace("Dialogue scene started at distance " + finalDistance)
    Notify("Dialogue scene requested")
EndFunction

Function StartResistanceCombat()
    ; Resist takes ownership away from the dialogue path even if the actor
    ; became invalid between the menu choice and this fragment call.
    StopOwnedDialogueCamera("Resist selected")

    If GetLivingEncounterAttackerCount() <= 0
        Trace("Resist combat cancelled: no living encounter attackers")
        UnlockPlayerMovement()
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    ; The hostile response takes over from the dialogue. The normal despawn
    ; timeout is cancelled because OnDeath now handles cleanup during combat.
    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Dialogue scene stopped before Resist combat")
    EndIf

    UnlockPlayerMovement()

    ResistanceCombatActive = true
    RegisterForViolateIntegration()

    Int attackersStarted = 0
    Int attackerIndex = 0
    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        Actor attacker = SpawnedEncounterAttackers[attackerIndex]

        If attacker && !attacker.IsDead()
            attacker.ClearLookAt()
            attacker.SetRelationshipRank(PlayerRef, -4)
            attacker.StartCombat(PlayerRef)
            attacker.EvaluatePackage()
            attackersStarted += 1
        EndIf

        attackerIndex += 1
    EndWhile

    If attackersStarted == 0 && SpawnedDiagnosticAttacker && !SpawnedDiagnosticAttacker.IsDead()
        SpawnedDiagnosticAttacker.ClearLookAt()
        SpawnedDiagnosticAttacker.SetRelationshipRank(PlayerRef, -4)
        SpawnedDiagnosticAttacker.StartCombat(PlayerRef)
        SpawnedDiagnosticAttacker.EvaluatePackage()
        attackersStarted = 1
    EndIf

    CancelTimer(TIMER_COMBAT_MONITOR)
    StartTimer(10.0, TIMER_COMBAT_MONITOR)

    Trace("Resist combat started with " + attackersStarted + " attacker(s)")
    Notify("Resist: combat started with " + attackersStarted + " attacker(s)")
EndFunction

Function RetireSubmissionActorsForDeferredDelete()
    Trace("Submit actor retirement started")

    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_DEATH_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)
    CancelTimer(TIMER_COMBAT_MONITOR)
    CancelTimer(TIMER_VIOLATE_CLEANUP)
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    CancelTimer(TIMER_SUBMIT_END_CLEANUP)
    CancelTimer(TIMER_DIALOGUE_APPROACH_TIMEOUT)
    CancelTimer(TIMER_SUBMIT_DEPARTURE)

    DialogueApproachActive = false
    StopOwnedDialogueCamera("Submit actor retirement")

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
    EndIf

    UnlockPlayerMovement()

    If ViolatePlayerScript
        UnregisterForCustomEvent(ViolatePlayerScript, "Vin_Event_Resume")
        ViolatePlayerScript = None
    EndIf
    ResistanceCombatActive = false

    If NAF_API
        UnregisterForCustomEvent(NAF_API, "OnSceneInit")
        UnregisterForCustomEvent(NAF_API, "OnSceneEnd")
        NAF_API = None
    EndIf

    SubmissionSceneActive = false
    SubmissionCleanupPending = false
    SubmissionResidualStopIssued = false

    If DeferredSubmissionAttackers == None
        DeferredSubmissionAttackers = new Actor[0]
    EndIf

    Int collectIndex = 0
    While SpawnedEncounterAttackers != None && collectIndex < SpawnedEncounterAttackers.Length
        Actor trackedAttacker = SpawnedEncounterAttackers[collectIndex]
        If trackedAttacker && DeferredSubmissionAttackers.Find(trackedAttacker) < 0
            DeferredSubmissionAttackers.Add(trackedAttacker)
        EndIf
        collectIndex += 1
    EndWhile

    If SpawnedDiagnosticAttacker && DeferredSubmissionAttackers.Find(SpawnedDiagnosticAttacker) < 0
        DeferredSubmissionAttackers.Add(SpawnedDiagnosticAttacker)
    EndIf

    SpawnedDiagnosticAttacker = None
    SpawnedEncounterAttackers = new Actor[0]

    If AttackerAlias
        AttackerAlias.Clear()
    EndIf

    Int retireIndex = 0
    While retireIndex < DeferredSubmissionAttackers.Length
        Actor retiredAttacker = DeferredSubmissionAttackers[retireIndex]

        If retiredAttacker
            UnregisterForRemoteEvent(retiredAttacker, "OnDeath")
            retiredAttacker.ClearLookAt()
            retiredAttacker.StopCombat()
            retiredAttacker.StopCombatAlarm()
            retiredAttacker.SetRelationshipRank(PlayerRef, 0)

            ; The actor disappears immediately, but remains a valid reference
            ; for NAF's serialized scene and asynchronous morph restoration.
            retiredAttacker.Disable(true)
        EndIf

        retireIndex += 1
    EndWhile

    ResetToIdle()
    DeferredSubmissionClearPasses = 0

    If DeferredSubmissionAttackers.Length > 0
        UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
        RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
        CancelTimer(TIMER_SUBMIT_DEFERRED_DELETE)
        StartTimer(SUBMIT_DEFERRED_DELETE_RETRY, TIMER_SUBMIT_DEFERRED_DELETE)
        Trace(DeferredSubmissionAttackers.Length + " hidden Submit actor(s) retained for NAF-safe deletion")
    Else
        UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
    EndIf
EndFunction

Function TryDeleteDeferredSubmissionAttackers()
    If DeferredSubmissionAttackers == None || DeferredSubmissionAttackers.Length <= 0
        DeferredSubmissionClearPasses = 0
        UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
        Return
    EndIf

    Bool nafReferenceStillPresent = false

    ; NAF may retain the PlayerRef side of an ended scene even after the
    ; temporary actors report no running scene. Treat either side as ownership.
    NAF:SceneId playerScene = NAF.GetSceneFromActor(PlayerRef)
    If playerScene.id1 != 0 || playerScene.id2 != 0
        nafReferenceStillPresent = true
    EndIf

    Int checkIndex = 0
    While checkIndex < DeferredSubmissionAttackers.Length
        Actor deferredAttacker = DeferredSubmissionAttackers[checkIndex]

        If deferredAttacker
            NAF:SceneId attackerScene = NAF.GetSceneFromActor(deferredAttacker)
            If attackerScene.id1 != 0 || attackerScene.id2 != 0
                nafReferenceStillPresent = true
            EndIf
        EndIf

        checkIndex += 1
    EndWhile

    If nafReferenceStillPresent
        DeferredSubmissionClearPasses = 0
        CancelTimer(TIMER_SUBMIT_DEFERRED_DELETE)
        StartTimer(SUBMIT_DEFERRED_DELETE_RETRY, TIMER_SUBMIT_DEFERRED_DELETE)
        Trace("Deferred Submit actors retained: NAF scene association still present")
        Return
    EndIf

    DeferredSubmissionClearPasses += 1
    If DeferredSubmissionClearPasses < SUBMIT_DELETE_CLEAR_PASSES_REQUIRED
        CancelTimer(TIMER_SUBMIT_DEFERRED_DELETE)
        StartTimer(SUBMIT_DEFERRED_DELETE_RETRY, TIMER_SUBMIT_DEFERRED_DELETE)
        Trace("Deferred Submit deletion clean pass " + DeferredSubmissionClearPasses + "/" + SUBMIT_DELETE_CLEAR_PASSES_REQUIRED)
        Return
    EndIf

    Actor[] attackersToDelete = DeferredSubmissionAttackers
    DeferredSubmissionAttackers = new Actor[0]
    DeferredSubmissionClearPasses = 0
    UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")

    Var[] deleteArgs = new Var[0]
    Int deletedActorCount = 0
    Int deleteIndex = 0

    While deleteIndex < attackersToDelete.Length
        Actor attackerToDelete = attackersToDelete[deleteIndex]
        If attackerToDelete
            attackerToDelete.Disable(true)
            attackerToDelete.CallFunctionNoWait("DeleteWhenAble", deleteArgs)
            deletedActorCount += 1
        EndIf
        deleteIndex += 1
    EndWhile

    Trace(deletedActorCount + " deferred Submit actor(s) released for engine-safe deletion")
EndFunction

Function CleanupDiagnosticAttacker(Bool abNotify = true)
    Trace("Encounter cleanup started")

    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_DEATH_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)
    CancelTimer(TIMER_COMBAT_MONITOR)
    CancelTimer(TIMER_VIOLATE_CLEANUP)
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    CancelTimer(TIMER_SUBMIT_END_CLEANUP)
    CancelTimer(TIMER_DIALOGUE_APPROACH_TIMEOUT)
    CancelTimer(TIMER_SUBMIT_DEPARTURE)
    Trace("Encounter timers cancelled")

    DialogueApproachActive = false

    ; The dialogue camera must release its target before the temporary actor is
    ; removed. Only stop a camera that this controller explicitly started.
    StopOwnedDialogueCamera("encounter cleanup")

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Dialogue scene stopped during encounter cleanup")
    EndIf

    UnlockPlayerMovement()

    If ViolatePlayerScript
        UnregisterForCustomEvent(ViolatePlayerScript, "Vin_Event_Resume")
        ViolatePlayerScript = None
        Trace("AAF Violate event registration released")
    EndIf
    ResistanceCombatActive = false

    If NAF_API
        UnregisterForCustomEvent(NAF_API, "OnSceneInit")
        UnregisterForCustomEvent(NAF_API, "OnSceneEnd")
        NAF_API = None
        Trace("NAF event registrations released")
    EndIf
    SubmissionSceneActive = false
    SubmissionCleanupPending = false
    SubmissionResidualStopIssued = false

    Actor[] attackersToDelete = new Actor[0]

    Int collectIndex = 0
    While SpawnedEncounterAttackers != None && collectIndex < SpawnedEncounterAttackers.Length
        Actor trackedAttacker = SpawnedEncounterAttackers[collectIndex]
        If trackedAttacker && attackersToDelete.Find(trackedAttacker) < 0
            attackersToDelete.Add(trackedAttacker)
        EndIf
        collectIndex += 1
    EndWhile

    ; Compatibility with saves created before v016a, where only the leader was
    ; stored and the group array did not exist yet.
    If SpawnedDiagnosticAttacker && attackersToDelete.Find(SpawnedDiagnosticAttacker) < 0
        attackersToDelete.Add(SpawnedDiagnosticAttacker)
    EndIf

    SpawnedDiagnosticAttacker = None
    SpawnedEncounterAttackers = new Actor[0]

    If AttackerAlias
        AttackerAlias.Clear()
        Trace("Attacker alias cleared")
    EndIf

    Var[] deleteArgs = new Var[0]
    Int deletedActorCount = 0
    Int deleteIndex = 0

    While deleteIndex < attackersToDelete.Length
        Actor attackerToDelete = attackersToDelete[deleteIndex]

        If attackerToDelete
            UnregisterForRemoteEvent(attackerToDelete, "OnDeath")
            attackerToDelete.ClearLookAt()

            ; Never call Delete() while the current cell is still attached.
            ; DeleteWhenAble waits for a safe cell state and is dispatched
            ; asynchronously for every temporary member of the group.
            attackerToDelete.Disable(true)
            attackerToDelete.CallFunctionNoWait("DeleteWhenAble", deleteArgs)
            deletedActorCount += 1
        EndIf

        deleteIndex += 1
    EndWhile

    Trace(deletedActorCount + " encounter actor(s) disabled; engine-safe deletion scheduled")

    If abNotify && deletedActorCount > 0
        Notify(deletedActorCount + " test actor(s) removed")
    EndIf

    ; A failed Submit may have armed the load hook before any actors entered
    ; deferred retirement. Do not leave that empty registration behind.
    If DeferredSubmissionAttackers == None || DeferredSubmissionAttackers.Length <= 0
        CancelTimer(TIMER_SUBMIT_DEFERRED_DELETE)
        UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
    EndIf

    ResetToIdle()
    Trace("Encounter cleanup completed; controller returned to idle")
EndFunction

Bool Function IsTrackedEncounterAttacker(Actor akActor)
    If !akActor
        Return false
    EndIf

    If akActor == SpawnedDiagnosticAttacker
        Return true
    EndIf

    If SpawnedEncounterAttackers != None && SpawnedEncounterAttackers.Find(akActor) >= 0
        Return true
    EndIf

    Return false
EndFunction

Int Function GetTrackedEncounterAttackerCount()
    Int attackerCount = 0
    Int attackerIndex = 0

    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        If SpawnedEncounterAttackers[attackerIndex]
            attackerCount += 1
        EndIf
        attackerIndex += 1
    EndWhile

    If SpawnedDiagnosticAttacker
        If SpawnedEncounterAttackers == None || SpawnedEncounterAttackers.Find(SpawnedDiagnosticAttacker) < 0
            attackerCount += 1
        EndIf
    EndIf

    Return attackerCount
EndFunction

Int Function GetLivingEncounterAttackerCount()
    Int attackerCount = 0
    Int attackerIndex = 0

    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        Actor attacker = SpawnedEncounterAttackers[attackerIndex]
        If attacker && !attacker.IsDead()
            attackerCount += 1
        EndIf
        attackerIndex += 1
    EndWhile

    If SpawnedDiagnosticAttacker
        If SpawnedEncounterAttackers == None || SpawnedEncounterAttackers.Find(SpawnedDiagnosticAttacker) < 0
            If !SpawnedDiagnosticAttacker.IsDead()
                attackerCount += 1
            EndIf
        EndIf
    EndIf

    Return attackerCount
EndFunction

Actor Function FindEncounterActorInRunningNAFScene()
    Int attackerIndex = 0

    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        Actor attacker = SpawnedEncounterAttackers[attackerIndex]

        If attacker
            NAF:SceneId runningScene = NAF.GetSceneFromActor(attacker)
            If runningScene.id1 != 0 || runningScene.id2 != 0
                If NAF.IsSceneRunning(runningScene)
                    Return attacker
                EndIf

                ; GetSceneFromActor can retain the identifier briefly after
                ; OnSceneEnd. It is not a running scene and must not be stopped
                ; again, or NAF Bridge may repeat its asynchronous actor cleanup.
                Trace("Ignoring stale ended NAF scene association for encounter actor")
            EndIf
        EndIf

        attackerIndex += 1
    EndWhile

    If SpawnedDiagnosticAttacker
        If SpawnedEncounterAttackers == None || SpawnedEncounterAttackers.Find(SpawnedDiagnosticAttacker) < 0
            NAF:SceneId leaderScene = NAF.GetSceneFromActor(SpawnedDiagnosticAttacker)
            If leaderScene.id1 != 0 || leaderScene.id2 != 0
                If NAF.IsSceneRunning(leaderScene)
                    Return SpawnedDiagnosticAttacker
                EndIf

                Trace("Ignoring stale ended NAF scene association for encounter leader")
            EndIf
        EndIf
    EndIf

    Return None
EndFunction

Function MonitorResistanceCombat()
    If GetTrackedEncounterAttackerCount() <= 0
        Return
    EndIf

    If GetLivingEncounterAttackerCount() <= 0
        ; The final OnDeath event schedules corpse cleanup.
        Return
    EndIf

    Bool attackerInRange = false
    Int attackerIndex = 0
    While SpawnedEncounterAttackers != None && attackerIndex < SpawnedEncounterAttackers.Length
        Actor attacker = SpawnedEncounterAttackers[attackerIndex]

        If attacker && !attacker.IsDead() && attacker.GetDistance(PlayerRef) < COMBAT_DESPAWN_DISTANCE
            attackerInRange = true
        EndIf

        attackerIndex += 1
    EndWhile

    ; Compatibility with a pre-v016a save that contains only the former
    ; single-attacker reference and no populated encounter array.
    If !attackerInRange && SpawnedDiagnosticAttacker
        If SpawnedEncounterAttackers == None || SpawnedEncounterAttackers.Find(SpawnedDiagnosticAttacker) < 0
            If !SpawnedDiagnosticAttacker.IsDead() && SpawnedDiagnosticAttacker.GetDistance(PlayerRef) < COMBAT_DESPAWN_DISTANCE
                attackerInRange = true
            EndIf
        EndIf
    EndIf

    If !attackerInRange
        Trace("Resist pursuit abandoned: all living attackers are out of range")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    ; AAF Violate temporarily stops combat when the player surrenders. The NPC
    ; must remain available even if IsInCombat() becomes false so Violate can
    ; reuse the NPC as an actor in its scene.
    StartTimer(10.0, TIMER_COMBAT_MONITOR)
EndFunction

Function RegisterForViolateIntegration()
    Quest violatePlayerQuest = Game.GetFormFromFile(0x00000F99, "AAF_Violate.esp") as Quest

    If !violatePlayerQuest
        Trace("AAF Violate integration unavailable: FPV_Player quest not found")
        Return
    EndIf

    ; FPV_OnHit is attached to alias 0 of the FPV_Player quest.
    ViolatePlayerScript = violatePlayerQuest.GetAlias(0) as FPV_OnHit

    If ViolatePlayerScript
        RegisterForCustomEvent(ViolatePlayerScript, "Vin_Event_Resume")
        Trace("AAF Violate integration registered")
    Else
        Trace("AAF Violate integration unavailable: FPV_OnHit script not found")
    EndIf
EndFunction

Event FPV_OnHit.Vin_Event_Resume(FPV_OnHit akSender, Var[] akArgs)
    If !ResistanceCombatActive || GetTrackedEncounterAttackerCount() <= 0
        Return
    EndIf

    Trace("Vin_Event_Resume received for the Resist encounter")
    CancelTimer(TIMER_COMBAT_MONITOR)
    CancelTimer(TIMER_VIOLATE_CLEANUP)

    ; The event is sent just before the final internal actor restoration. A
    ; short delay prevents the NPC from being deleted during that loop.
    StartTimer(5.0, TIMER_VIOLATE_CLEANUP)
EndEvent

Function MonitorDialogueScene()
    If UI.IsMenuOpen("DialogueMenu")
        DialogueMenuWasOpened = true
        DialogueMonitorTicks = 0
        StartTimer(0.5, TIMER_SCENE_MONITOR)
    ElseIf !DialogueMenuWasOpened && SpawnedDiagnosticAttacker && DialogueMonitorTicks < 30
        ; Pendant la menace d'introduction, DialogueMenu n'est pas encore ouvert.
        ; The lock must remain active until the menu appears.
        DialogueMonitorTicks += 1
        StartTimer(0.5, TIMER_SCENE_MONITOR)
    ElseIf !DialogueMenuWasOpened
        Trace("DialogueMenu did not open before the safety timeout")
        CleanupDiagnosticAttacker(false)
    Else
        StopOwnedDialogueCamera("dialogue menu closed")
        UnlockPlayerMovement()
        Trace("Dialogue ended; player movement restored")
    EndIf
EndFunction

Function StopOwnedDialogueCamera(String asReason = "")
    If !DialogueCameraActive
        Return
    EndIf

    ; Clear ownership first so a second cleanup stack cannot stop another
    ; dialogue camera after this encounter has already released its own.
    DialogueCameraActive = false
    Game.StopDialogueCamera()

    If asReason != ""
        Trace("Dialogue camera stopped: " + asReason)
    Else
        Trace("Dialogue camera stopped")
    EndIf
EndFunction

Function LockPlayerMovement()
    UnlockPlayerMovement()

    DialogueMenuWasOpened = false
    DialogueMonitorTicks = 0

    ; A dedicated layer blocks locomotion only. Unlike SetRestrained, it still
    ; allows the player to rotate the camera and face the NPC.
    DialogueInputLayer = InputEnableLayer.Create()
    If DialogueInputLayer
        DialogueInputLayer.DisablePlayerControls(abMovement = true, abRunning = true)
        DialogueInputLayer.EnableJumping(false)
        Trace("Movement layer created; walking, running and jumping locked")
        Notify("Dialogue: player movement locked")
    Else
        Trace("ERROR: unable to create the movement layer")
        Notify("ERROR: unable to lock player movement")
    EndIf
EndFunction

Function UnlockPlayerMovement()
    If DialogueInputLayer
        DialogueInputLayer.Delete()
        DialogueInputLayer = None
        Trace("Player movement unlocked")
    EndIf

    DialogueMenuWasOpened = false
    DialogueMonitorTicks = 0
EndFunction

Int Function GetLocationType(Location akLocation)
    If !akLocation
        Return 0
    EndIf

    WorkshopScript workshopRef = WorkshopParent.GetWorkshopFromLocation(akLocation)

    If akLocation.HasKeyword(LocTypeWorkshopSettlement) && workshopRef && workshopRef.OwnedByPlayer
        Return 1
    ElseIf akLocation.HasKeyword(LocTypeSettlement)
        Return 2
    ElseIf akLocation.HasKeyword(LocTypeDungeon) || akLocation.HasKeyword(LocTypeDungeonGlowingSea)
        Return 3
    EndIf

    Return 0
EndFunction

Float Function GetChanceForLocationType(Int aiLocationType)
    If aiLocationType == 1
        Return RHI_NDN_ChancePlayerSettlement.GetValue()
    ElseIf aiLocationType == 2
        Return RHI_NDN_ChanceTown.GetValue()
    ElseIf aiLocationType == 3
        Return RHI_NDN_ChanceDungeon.GetValue()
    EndIf

    Return RHI_NDN_ChanceOutdoor.GetValue()
EndFunction

String Function GetLocationTypeName(Int aiLocationType)
    If aiLocationType == 1
        Return "player settlement"
    ElseIf aiLocationType == 2
        Return "town/NPC settlement"
    ElseIf aiLocationType == 3
        Return "dungeon"
    EndIf

    Return "outdoor/other"
EndFunction

Function ResetToIdle()
    CancelTimer(TIMER_WAKEUP)
    SleepStartTime = 0.0
    DesiredWakeTime = 0.0
    LastBed = None
    CurrentState = STATE_IDLE
EndFunction

Function Trace(String asMessage)
    Debug.Trace("[RHI_NDN] " + asMessage)
EndFunction

Function Notify(String asMessage)
    If RHI_NDN_Debug.GetValue() == 1.0
        Debug.Notification("[RHI_NDN] " + asMessage)
    EndIf
EndFunction

Event OnQuestShutdown()
    CancelTimer(TIMER_WAKEUP)
    CancelTimer(TIMER_SUBMIT_DEFERRED_DELETE)
    CleanupDiagnosticAttacker(false)
    UnregisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")

    ; Quest shutdown is the final ownership boundary. Do not leave disabled
    ; PlaceAtMe references behind if the controller is explicitly stopped.
    If DeferredSubmissionAttackers != None && DeferredSubmissionAttackers.Length > 0
        Var[] deleteArgs = new Var[0]
        Int deleteIndex = 0
        While deleteIndex < DeferredSubmissionAttackers.Length
            Actor deferredAttacker = DeferredSubmissionAttackers[deleteIndex]
            If deferredAttacker
                deferredAttacker.Disable(true)
                deferredAttacker.CallFunctionNoWait("DeleteWhenAble", deleteArgs)
            EndIf
            deleteIndex += 1
        EndWhile
        DeferredSubmissionAttackers = new Actor[0]
        DeferredSubmissionClearPasses = 0
    EndIf

    UnregisterForPlayerSleep()
    CurrentState = STATE_IDLE
    Trace("Controller stopped")
EndEvent
