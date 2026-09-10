Scriptname RHI_NDN_Controller extends Quest

Actor Property PlayerRef Auto Const Mandatory
WorkshopParentScript Property WorkshopParent Auto Const Mandatory

GlobalVariable Property RHI_NDN_Enabled Auto Const Mandatory
GlobalVariable Property RHI_NDN_Debug Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChancePlayerSettlement Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceTown Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceDungeon Auto Const Mandatory
GlobalVariable Property RHI_NDN_ChanceOutdoor Auto Const Mandatory

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
Float Property COMBAT_DESPAWN_DISTANCE = 4096.0 AutoReadOnly
Float Property SUBMIT_SCENE_DURATION = 60.0 Auto Const
String Property SUBMIT_SCENE_META = "RHI_NDN_SUBMIT" AutoReadOnly

Actor SpawnedDiagnosticAttacker = None
InputEnableLayer DialogueInputLayer = None
Bool DialogueMenuWasOpened = false
Int DialogueMonitorTicks = 0
Bool ResistanceCombatActive = false
FPV_OnHit ViolatePlayerScript = None
AAF:AAF_API NAF_API = None
Bool SubmissionSceneActive = false

Event OnQuestInit()
    Trace("Controller initialising")
    RegisterForPlayerSleep()
    CurrentState = STATE_IDLE
    Notify("Contrôleur initialisé")
EndEvent

Event OnPlayerSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime, ObjectReference akBed)
    If RHI_NDN_Enabled.GetValue() == 0.0
        Return
    EndIf

    If CurrentState != STATE_IDLE
        Trace("Sommeil ignoré : contrôleur non disponible, état " + CurrentState)
        Return
    EndIf

    If PlayerRef.IsInCombat()
        Trace("Sommeil ignoré : joueur en combat")
        Return
    EndIf

    SleepStartTime = afSleepStartTime
    DesiredWakeTime = afDesiredSleepEndTime
    LastBed = akBed
    CurrentState = STATE_SLEEPING
    Trace("Début du sommeil")
EndEvent

Event OnPlayerSleepStop(Bool abInterrupted, ObjectReference akBed)
    If CurrentState != STATE_SLEEPING
        Return
    EndIf

    If abInterrupted
        Trace("Sommeil interrompu : abandon")
        ResetToIdle()
        Return
    EndIf

    CurrentState = STATE_EVALUATING
    CancelTimer(TIMER_WAKEUP)
    StartTimer(3.0, TIMER_WAKEUP)
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
        Trace("AAF Violate a rendu les acteurs ; nettoyage de l'agresseur Resist")
        CleanupDiagnosticAttacker(false)
    ElseIf aiTimerID == TIMER_SUBMIT_FAIL_CLEANUP
        Trace("La scène Submit n'a pas démarré ; nettoyage de sécurité")
        CleanupDiagnosticAttacker(false)
    ElseIf aiTimerID == TIMER_SUBMIT_END_CLEANUP
        Trace("Scène Submit terminée ; nettoyage de l'agresseur")
        CleanupDiagnosticAttacker(false)
    EndIf
EndEvent

Event Actor.OnDeath(Actor akSender, Actor akKiller)
    If akSender != SpawnedDiagnosticAttacker
        Return
    EndIf

    Trace("Le PNJ de la rencontre est mort ; tueur : " + akKiller)

    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_COMBAT_MONITOR)

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Scène de dialogue arrêtée après la mort du PNJ")
    EndIf

    If AttackerAlias && AttackerAlias.GetReference() == akSender
        AttackerAlias.Clear()
    EndIf

    ; OnDeath arrive lorsque l'acteur a fini de mourir. Un court délai laisse
    ; néanmoins le moteur terminer ses traitements avant Disable/Delete.
    CancelTimer(TIMER_DEATH_CLEANUP)
    StartTimer(2.0, TIMER_DEATH_CLEANUP)
EndEvent

Function EvaluateWakeup()
    If RHI_NDN_Enabled.GetValue() == 0.0
        ResetToIdle()
        Return
    EndIf

    If PlayerRef.IsInCombat()
        Trace("Réveil annulé : joueur en combat")
        ResetToIdle()
        Return
    EndIf

    Location currentLocation = PlayerRef.GetCurrentLocation()
    Int locationType = GetLocationType(currentLocation)
    Float configuredChance = GetChanceForLocationType(locationType)
    Int roll = Utility.RandomInt(1, 100)
    Bool rollSucceeded = roll <= configuredChance

    Trace("Réveil détecté")
    Trace("Type de lieu : " + GetLocationTypeName(locationType))
    Trace("Tirage : " + roll + " / chance : " + configuredChance)

    If rollSucceeded
        Trace("Résultat : succès")
        Notify("Réveil : " + GetLocationTypeName(locationType) + " | SUCCÈS " + roll + "/" + configuredChance)
        SpawnDiagnosticAttacker()
    Else
        Trace("Résultat : échec")
        Notify("Réveil : " + GetLocationTypeName(locationType) + " | ÉCHEC " + roll + "/" + configuredChance)
    EndIf

    ; Une rencontre active conserve l'état STATE_ENCOUNTER jusqu'au nettoyage.
    If !SpawnedDiagnosticAttacker
        ResetToIdle()
    EndIf
EndFunction

Function StartSubmissionScene()
    Actor attacker = SpawnedDiagnosticAttacker

    If !attacker || attacker.IsDead()
        Trace("Submit annulé : aucun agresseur valide")
        UnlockPlayerMovement()
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)
    CancelTimer(TIMER_COMBAT_MONITOR)

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Scène de dialogue arrêtée pour lancer Submit")
    EndIf

    UnlockPlayerMovement()

    ; Submit n'est pas une défaite de combat. On neutralise donc proprement
    ; l'acteur avant de le transmettre au pont AAF/NAF.
    attacker.StopCombat()
    attacker.StopCombatAlarm()
    attacker.SetRelationshipRank(PlayerRef, 0)
    attacker.EvaluatePackage()

    NAF_API = AAF:AAF_API.GetAPI()
    If !NAF_API
        Trace("Submit impossible : API AAF/NAFBridge introuvable")
        Notify("ERREUR : NAFBridge introuvable")
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    RegisterForCustomEvent(NAF_API, "OnSceneInit")
    RegisterForCustomEvent(NAF_API, "OnSceneEnd")

    AAF:AAF_API:SceneSettings submitSettings = NAF_API.GetSceneSettings()
    submitSettings.duration = SUBMIT_SCENE_DURATION
    submitSettings.preventFurniture = true
    submitSettings.skipWalk = true
    submitSettings.isNPCControlled = true
    submitSettings.ignoreCombat = true
    submitSettings.includeTags = "Aggressive"
    submitSettings.meta = SUBMIT_SCENE_META

    Actor[] submitActors = new Actor[2]
    ; Comme dans Dangerous Nights : la victime est en première position.
    submitActors[0] = PlayerRef
    submitActors[1] = attacker

    SubmissionSceneActive = true
    ; Le garde-fou est armé avant StartScene : NAF peut envoyer OnSceneInit
    ; presque immédiatement.
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    StartTimer(20.0, TIMER_SUBMIT_FAIL_CLEANUP)
    ; Certaines versions de l'API AAF-compatible déclarent StartScene sans
    ; valeur de retour. On s'appuie donc sur OnSceneInit et sur le garde-fou.
    NAF_API.StartScene(submitActors, submitSettings)
    Trace("Submit transmis à NAFBridge")
    Notify("Submit : scène NAF demandée")
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
        Trace("Scène Submit démarrée par NAF")
    Else
        String failureReason = "raison inconnue"
        If akArgs.Length > 1
            failureReason = akArgs[1] as String
        EndIf
        Trace("Échec de la scène Submit : " + failureReason)
        Notify("ERREUR NAF : " + failureReason)
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
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    CancelTimer(TIMER_SUBMIT_END_CLEANUP)

    ; NAFBridge termine encore sa propre restauration après l'envoi de
    ; OnSceneEnd. Deux secondes évitent de supprimer l'acteur sous ses pieds.
    StartTimer(2.0, TIMER_SUBMIT_END_CLEANUP)
    Trace("Fin de la scène Submit reçue de NAF")
EndEvent

Function SpawnDiagnosticAttacker()
    CleanupDiagnosticAttacker(false)

    Int poolSize = RHI_NDN_AttackerPool.GetSize()

    If poolSize <= 0
        Trace("Le catalogue d'agresseurs est vide")
        Notify("ERREUR : catalogue de PNJ vide")
        Return
    EndIf

    Int selectedIndex = Utility.RandomInt(0, poolSize - 1)
    ActorBase selectedActorBase = RHI_NDN_AttackerPool.GetAt(selectedIndex) as ActorBase

    If !selectedActorBase
        Trace("Entrée ActorBase invalide dans le catalogue à l'index " + selectedIndex)
        Notify("ERREUR : entrée de PNJ invalide")
        Return
    EndIf

    ObjectReference spawnedReference = PlayerRef.PlaceAtMe(selectedActorBase, 1, false, false, false)
    Actor spawnedActor = spawnedReference as Actor

    If !spawnedActor
        Trace("Échec du spawn diagnostique")
        Notify("ERREUR : impossible de créer le PNJ test")
        Return
    EndIf

    SpawnedDiagnosticAttacker = spawnedActor
    CurrentState = STATE_ENCOUNTER
    SpawnedDiagnosticAttacker.ModValue(UnarmedDamageAV, AttackerUnarmedDamageBonus)
    Trace("Bonus de dégâts à mains nues appliqué : " + AttackerUnarmedDamageBonus)
    RegisterForRemoteEvent(SpawnedDiagnosticAttacker, "OnDeath")
    SpawnedDiagnosticAttacker.MoveTo(PlayerRef, 100.0, 0.0, 0.0, true)

    AttackerAlias.ForceRefTo(SpawnedDiagnosticAttacker)

    If AttackerAlias.GetReference() == SpawnedDiagnosticAttacker
        Trace("Alias attacker affecté au PNJ diagnostique")
        Notify("Alias attacker correctement affecté")

        ; La scène Player Dialogue doit démarrer seulement après ForceRefTo(),
        ; afin que son acteur AttackerAlias soit déjà résolu.
        Utility.Wait(0.25)
        LockPlayerMovement()
        RHI_NDN_AttackerDialogueScene.Start()
        CancelTimer(TIMER_SCENE_MONITOR)
        StartTimer(0.5, TIMER_SCENE_MONITOR)
        Trace("Scène de dialogue démarrée")
        Notify("Scène de dialogue demandée")
    Else
        Trace("Échec de l'affectation de l'alias attacker")
        Notify("ERREUR : alias attacker non affecté")
    EndIf

    Trace("PNJ diagnostique créé depuis l'index " + selectedIndex)
    Notify("PNJ test apparu pour 60 secondes maximum")
    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    StartTimer(60.0, TIMER_DIAGNOSTIC_CLEANUP)
EndFunction

Function StartResistanceCombat()
    Actor attacker = SpawnedDiagnosticAttacker

    If !attacker
        Trace("Combat Resist annulé : aucun agresseur actif")
        UnlockPlayerMovement()
        Return
    EndIf

    If attacker.IsDead()
        Trace("Combat Resist annulé : l'agresseur est déjà mort")
        UnlockPlayerMovement()
        Return
    EndIf

    ; La réponse hostile prend le relais sur le dialogue. Le délai de despawn
    ; normal est annulé : pendant le combat, OnDeath assure désormais le nettoyage.
    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Scène de dialogue arrêtée pour lancer le combat Resist")
    EndIf

    UnlockPlayerMovement()

    ResistanceCombatActive = true
    RegisterForViolateIntegration()

    attacker.SetRelationshipRank(PlayerRef, -4)
    attacker.StartCombat(PlayerRef)
    attacker.EvaluatePackage()

    CancelTimer(TIMER_COMBAT_MONITOR)
    StartTimer(10.0, TIMER_COMBAT_MONITOR)

    Trace("Combat Resist lancé contre le joueur")
    Notify("Resist : combat lancé")
EndFunction

Function CleanupDiagnosticAttacker(Bool abNotify = true)
    CancelTimer(TIMER_DIAGNOSTIC_CLEANUP)
    CancelTimer(TIMER_DEATH_CLEANUP)
    CancelTimer(TIMER_SCENE_MONITOR)
    CancelTimer(TIMER_COMBAT_MONITOR)
    CancelTimer(TIMER_VIOLATE_CLEANUP)
    CancelTimer(TIMER_SUBMIT_FAIL_CLEANUP)
    CancelTimer(TIMER_SUBMIT_END_CLEANUP)
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

    If RHI_NDN_AttackerDialogueScene && RHI_NDN_AttackerDialogueScene.IsPlaying()
        RHI_NDN_AttackerDialogueScene.Stop()
        Trace("Scène de dialogue arrêtée")
    EndIf

    Actor attackerToDelete = SpawnedDiagnosticAttacker
    SpawnedDiagnosticAttacker = None

    If attackerToDelete
        UnregisterForRemoteEvent(attackerToDelete, "OnDeath")
    EndIf

    If AttackerAlias
        AttackerAlias.Clear()
    EndIf

    If attackerToDelete
        attackerToDelete.Disable(false)
        attackerToDelete.Delete()
        Trace("PNJ diagnostique supprimé")

        If abNotify
            Notify("PNJ test supprimé")
        EndIf
    EndIf

    ResetToIdle()
EndFunction

Function MonitorResistanceCombat()
    Actor attacker = SpawnedDiagnosticAttacker

    If !attacker
        Return
    EndIf

    If attacker.IsDead()
        ; L'événement OnDeath programme déjà le nettoyage du corps.
        Return
    EndIf

    Float distanceToPlayer = attacker.GetDistance(PlayerRef)

    If distanceToPlayer >= COMBAT_DESPAWN_DISTANCE
        Trace("Poursuite Resist abandonnée : distance " + distanceToPlayer)
        CleanupDiagnosticAttacker(false)
        Return
    EndIf

    ; AAF Violate arrête temporairement le combat lors de la reddition du joueur.
    ; Le PNJ doit donc rester disponible même si IsInCombat() devient faux, afin
    ; que Violate puisse le reprendre comme acteur de sa scène.
    StartTimer(10.0, TIMER_COMBAT_MONITOR)
EndFunction

Function RegisterForViolateIntegration()
    Quest violatePlayerQuest = Game.GetFormFromFile(0x00000F99, "AAF_Violate.esp") as Quest

    If !violatePlayerQuest
        Trace("Intégration AAF Violate indisponible : quête FPV_Player introuvable")
        Return
    EndIf

    ; FPV_OnHit est attaché à l'alias 0 de la quête FPV_Player.
    ViolatePlayerScript = violatePlayerQuest.GetAlias(0) as FPV_OnHit

    If ViolatePlayerScript
        RegisterForCustomEvent(ViolatePlayerScript, "Vin_Event_Resume")
        Trace("Intégration AAF Violate enregistrée")
    Else
        Trace("Intégration AAF Violate indisponible : script FPV_OnHit introuvable")
    EndIf
EndFunction

Event FPV_OnHit.Vin_Event_Resume(FPV_OnHit akSender, Var[] akArgs)
    If !ResistanceCombatActive || !SpawnedDiagnosticAttacker
        Return
    EndIf

    Trace("Événement Vin_Event_Resume reçu pour la rencontre Resist")
    CancelTimer(TIMER_COMBAT_MONITOR)
    CancelTimer(TIMER_VIOLATE_CLEANUP)

    ; L'événement est envoyé juste avant la dernière restauration interne des
    ; acteurs. Un court délai évite de supprimer le PNJ pendant cette boucle.
    StartTimer(5.0, TIMER_VIOLATE_CLEANUP)
EndEvent

Function MonitorDialogueScene()
    If UI.IsMenuOpen("DialogueMenu")
        DialogueMenuWasOpened = true
        DialogueMonitorTicks = 0
        StartTimer(0.5, TIMER_SCENE_MONITOR)
    ElseIf !DialogueMenuWasOpened && SpawnedDiagnosticAttacker && DialogueMonitorTicks < 30
        ; Pendant la menace d'introduction, DialogueMenu n'est pas encore ouvert.
        ; Le verrou doit rester actif jusqu'à son apparition.
        DialogueMonitorTicks += 1
        StartTimer(0.5, TIMER_SCENE_MONITOR)
    ElseIf !DialogueMenuWasOpened
        Trace("DialogueMenu ne s'est pas ouvert dans le délai de sécurité")
        CleanupDiagnosticAttacker(false)
    Else
        UnlockPlayerMovement()
        Trace("Fin du dialogue détectée ; déplacement du joueur rétabli")
    EndIf
EndFunction

Function LockPlayerMovement()
    UnlockPlayerMovement()

    DialogueMenuWasOpened = false
    DialogueMonitorTicks = 0

    ; Une couche dédiée bloque uniquement la locomotion. Contrairement à
    ; SetRestrained, elle laisse le joueur tourner la caméra et faire face au PNJ.
    DialogueInputLayer = InputEnableLayer.Create()
    If DialogueInputLayer
        DialogueInputLayer.DisablePlayerControls(abMovement = true, abRunning = true)
        DialogueInputLayer.EnableJumping(false)
        Trace("Couche de déplacement créée ; marche, course et saut verrouillés")
        Notify("Dialogue : déplacements verrouillés")
    Else
        Trace("ERREUR : impossible de créer la couche de déplacement")
        Notify("ERREUR : verrouillage des déplacements impossible")
    EndIf
EndFunction

Function UnlockPlayerMovement()
    If DialogueInputLayer
        DialogueInputLayer.Delete()
        DialogueInputLayer = None
        Trace("Déplacement du joueur déverrouillé")
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
        Return "colonie du joueur"
    ElseIf aiLocationType == 2
        Return "ville/colonie PNJ"
    ElseIf aiLocationType == 3
        Return "donjon"
    EndIf

    Return "extérieur/autre"
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
    CleanupDiagnosticAttacker(false)
    UnregisterForPlayerSleep()
    CurrentState = STATE_IDLE
    Trace("Contrôleur arrêté")
EndEvent
