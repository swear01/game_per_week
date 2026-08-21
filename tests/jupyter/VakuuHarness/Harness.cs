using System.Reflection;
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Context;
using MegaCrit.Sts2.Core.DevConsole;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Events;
using MegaCrit.Sts2.Core.Hooks;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Modding;
using MegaCrit.Sts2.Core.Map;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Nodes;
using MegaCrit.Sts2.Core.Nodes.Rooms;
using MegaCrit.Sts2.Core.Nodes.Screens.CardSelection;
using MegaCrit.Sts2.Core.Nodes.Screens.CharacterSelect;
using MegaCrit.Sts2.Core.Nodes.Screens.MainMenu;
using MegaCrit.Sts2.Core.Nodes.Screens.Map;
using MegaCrit.Sts2.Core.Runs;

namespace VakuuHarness;

[ModInitializer(nameof(Initialize))]
public static class Harness
{
    private const int WarmupFrames = 600;
    private const int HeartbeatInterval = 120;
    private const int EventOptionDelayFrames = 180;
    private const int StartingRelicWaitFrames = 600;
    private const int CombatWaitFrames = 360;
    private const int WinWaitFrames = 240;
    private const int ActWaitFrames = 240;
    private const int MaxTestFrames = 18_000;
    private static readonly Harmony Harmony = new("vakuu.harness");
    private static readonly HashSet<string> VakuuRelicIds =
    [
        "BLOOD_SOAKED_ROSE",
        "FIDDLE",
        "PRESERVED_FOG",
        "SERE_TALON",
        "DISTINGUISHED_CAPE",
        "CHOICES_PARADOX",
        "MUSIC_BOX",
        "LORDS_PARASOL",
        "JEWELED_MASK",
        "VAKUU_CONTRACT"
    ];
    private static bool _started;
    private static bool _selectionConfirmed;
    private static bool _optionChosen;
    private static EventModel? _pendingEventModel;
    private static Task? _optionTask;
    private static Task? _proceedTask;
    private static bool _startingRelicsLogged;
    private static int _startingRelicWaitFrames;
    private static string? _lastStartingRelicSignature;
    private static bool _needFight;
    private static bool _fightCommandSent;
    private static Task? _travelTask;
    private static bool _combatLogged;
    private static bool _combatChoiceConfirmed;
    private static bool _endTurnCommandSent;
    private static bool _winCommandSent;
    private static bool _actCommandSent;
    private static bool _neowCommandSent;
    private static Task? _commandTask;
    private static string? _commandName;
    private static bool _commandCompletionLogged;
    private static bool _finished;
    private static bool _failed;
    private static int _optionDelay;
    private static int _combatFrames;
    private static int _winFrames;
    private static int _actFrames;
    private static int _autoPlayCount;
    private static readonly List<string> AutoPlayedCards = [];
    private static readonly List<int> AutoPhaseTurns = [];
    private static readonly List<int> AutoPlayTurns = [];
    private static bool _openedSingleplayer;
    private static bool _openedCharacterSelect;
    private static int _frames;
    private static int _totalFrames;

    public static void Initialize()
    {
        var autoPlay = AccessTools.Method(typeof(CardCmd), nameof(CardCmd.AutoPlay));
        if (autoPlay == null)
        {
            throw new MissingMethodException(typeof(CardCmd).FullName, nameof(CardCmd.AutoPlay));
        }

        Harmony.Patch(
            autoPlay,
            prefix: new HarmonyMethod(typeof(Harness), nameof(AutoPlayPrefix)),
            postfix: new HarmonyMethod(typeof(Harness), nameof(AutoPlayPostfix)));
        var autoPlayPatches = Harmony.GetPatchInfo(autoPlay);
        GD.Print($"[VakuuHarness] AutoPlay patches prefixes={autoPlayPatches?.Prefixes.Count ?? -1} postfixes={autoPlayPatches?.Postfixes.Count ?? -1}");

        var contractType = AccessTools.TypeByName("VakuuPlayer.Relics.VakuuContract")
            ?? throw new MissingMethodException("VakuuPlayer.Relics.VakuuContract");
        var contractHook = AccessTools.Method(contractType, "AfterAutoPrePlayPhaseEnteredLate")
            ?? throw new MissingMethodException(contractType.FullName, "AfterAutoPrePlayPhaseEnteredLate");
        Harmony.Patch(contractHook, prefix: new HarmonyMethod(typeof(Harness), nameof(ContractPrefix)));
        var contractPatches = Harmony.GetPatchInfo(contractHook);
        GD.Print($"[VakuuHarness] Contract hook found={contractHook != null} declaring={contractHook?.DeclaringType?.FullName} virtual={contractHook?.IsVirtual} base={contractHook?.GetBaseDefinition().DeclaringType?.FullName} prefixes={contractPatches?.Prefixes.Count ?? -1} postfixes={contractPatches?.Postfixes.Count ?? -1}");

        var hookMethod = AccessTools.Method(typeof(Hook), nameof(Hook.AfterAutoPrePlayPhaseEntered));
        if (hookMethod == null)
        {
            throw new MissingMethodException(typeof(Hook).FullName, nameof(Hook.AfterAutoPrePlayPhaseEntered));
        }
        Harmony.Patch(hookMethod, prefix: new HarmonyMethod(typeof(Harness), nameof(HookPrefix)));

        var runAutoPrePlay = AccessTools.Method(typeof(CombatManager), "RunAutoPrePlayPhase");
        if (runAutoPrePlay == null)
        {
            throw new MissingMethodException(typeof(CombatManager).FullName, "RunAutoPrePlayPhase");
        }
        Harmony.Patch(runAutoPrePlay, prefix: new HarmonyMethod(typeof(Harness), nameof(RunAutoPrePlayPrefix)));

        var method = AccessTools.Method(typeof(NCharacterSelectScreen), nameof(NCharacterSelectScreen.SelectCharacter));
        var patches = method == null ? null : Harmony.GetPatchInfo(method);
        GD.Print($"[VakuuHarness] SelectCharacter patches prefixes={patches?.Prefixes.Count ?? -1} postfixes={patches?.Postfixes.Count ?? -1} finalizers={patches?.Finalizers.Count ?? -1}");
        if (Engine.GetMainLoop() is not SceneTree tree)
        {
            throw new InvalidOperationException("VakuuHarness requires a SceneTree main loop.");
        }

        tree.ProcessFrame += () => Tick(tree);
        GD.Print("[VakuuHarness] attached");
    }

    private static void HookPrefix()
    {
        GD.Print($"[VakuuHarness] Hook.AfterAutoPrePlayPhaseEntered called fightSent={_fightCommandSent}");
    }

    private static void RunAutoPrePlayPrefix()
    {
        if (!_fightCommandSent || _winCommandSent)
        {
            return;
        }

        try
        {
            var turn = CurrentCombatTurn();
            AutoPhaseTurns.Add(turn);
            GD.Print($"[VakuuHarness] auto-phase turn={turn} fightSent={_fightCommandSent}");
        }
        catch (Exception e)
        {
            GD.PrintErr($"[VakuuHarness] could not record auto-phase: {e}");
        }
    }

    private static void ContractPrefix()
    {
        GD.Print($"[VakuuHarness] Contract hook called fightSent={_fightCommandSent}");
    }

    private static void AutoPlayPrefix(CardModel card)
    {
        if (_fightCommandSent && !_winCommandSent)
        {
            if (card == null)
            {
                GD.PrintErr("[VakuuHarness] AutoPlay received a null card in prefix");
                return;
            }
            GD.Print($"[VakuuHarness] AutoPlay entered card={card.Id.Entry}");
        }
    }

    private static void AutoPlayPostfix(CardModel card)
    {
        if (!_fightCommandSent || _winCommandSent)
        {
            return;
        }

        if (card == null)
        {
            GD.PrintErr("[VakuuHarness] AutoPlay received a null card in postfix");
            return;
        }

        _autoPlayCount++;
        AutoPlayedCards.Add(card.Id.Entry);
        var turn = CurrentCombatTurn();
        AutoPlayTurns.Add(turn);
        GD.Print($"[VakuuHarness] auto-played card={card.Id.Entry} count={_autoPlayCount} turn={turn}");
    }

    private static void Tick(SceneTree tree)
    {
        if (_failed || _finished)
        {
            return;
        }

        if (++_totalFrames > MaxTestFrames)
        {
            Fail($"harness exceeded {MaxTestFrames} frames without completing");
            return;
        }

        if (++_frames < WarmupFrames)
        {
            return;
        }

        if (_frames % HeartbeatInterval == 0)
        {
            var names = new List<string>();
            Collect(tree.Root, names, 0);
            GD.Print($"[VakuuHarness] heartbeat frame={_frames} nodes={string.Join(",", names.Take(80))}");
        }

        try
        {
            var root = tree.Root;
            if (_started)
            {
                if (!_optionChosen)
                {
                    var eventRoom = FindNode<NEventRoom>(root);
                    var eventModel = eventRoom == null
                        ? null
                        : typeof(NEventRoom).GetField("_event", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(eventRoom) as EventModel;
                    if (eventModel?.Id.Entry == "VAKUU")
                    {
                        if (eventModel.CurrentOptions.Count != 1)
                        {
                            if (++_optionDelay >= EventOptionDelayFrames)
                            {
                                Fail($"Vakuu event expected one option, found {eventModel.CurrentOptions.Count}");
                            }
                            return;
                        }

                        if (++_optionDelay < EventOptionDelayFrames)
                        {
                            return;
                        }

                        if (eventModel.Owner == null)
                        {
                            throw new InvalidOperationException("Vakuu event has no owner.");
                        }

                        _optionChosen = true;
                        _pendingEventModel = eventModel;
                        GD.Print($"[VakuuHarness] choosing Accept; relics before={eventModel.Owner.Relics.Count}");
                        _optionTask = ChooseOptionAsync(eventModel);
                        return;
                    }
                }

                if (_optionTask != null)
                {
                    if (!TaskCompleted(_optionTask, "event choice"))
                    {
                        return;
                    }

                    _optionTask = null;
                }

                if (_optionChosen && !_needFight)
                {
                    if (_proceedTask == null)
                    {
                        var owner = _pendingEventModel?.Owner
                            ?? throw new InvalidOperationException("Vakuu event owner was lost before proceeding.");
                        GD.Print($"[VakuuHarness] Accept complete; relics={owner.Relics.Count} ids={string.Join(",", owner.Relics.Select(r => r.Id.Entry))}");
                        _proceedTask = NEventRoom.Proceed();
                        return;
                    }

                    if (!TaskCompleted(_proceedTask, "event proceed"))
                    {
                        return;
                    }

                    _proceedTask = null;
                    _pendingEventModel = null;
                    _needFight = true;
                }

                if (!_startingRelicsLogged)
                {
                    _startingRelicsLogged = LogStartingRelics();
                    if (!_startingRelicsLogged && ++_startingRelicWaitFrames >= StartingRelicWaitFrames)
                    {
                        Fail("expected Vakuu relics were not all acquired");
                        return;
                    }
                }

                if (_needFight && !_fightCommandSent)
                {
                    if (_travelTask != null)
                    {
                        if (!TaskCompleted(_travelTask, "map travel"))
                        {
                            return;
                        }

                        GD.Print("[VakuuHarness] actual map travel complete");
                        _travelTask = null;
                        _fightCommandSent = true;
                        return;
                    }

                    var map = FindNode<NMapScreen>(root);
                    if (map == null)
                    {
                        return;
                    }

                    if (!map.IsOpen)
                    {
                        map.Open();
                    }
                    map.SetDebugTravelEnabled(true);
                    var mapField = typeof(NMapScreen).GetField(
                        "_mapPointDictionary", BindingFlags.Instance | BindingFlags.NonPublic);
                    var mapPoints = mapField?.GetValue(map) as IReadOnlyDictionary<MapCoord, NMapPoint>;
                    var point = mapPoints?.Values.FirstOrDefault(p => p.Point.PointType == MapPointType.Monster);
                    if (point == null)
                    {
                        throw new InvalidOperationException("Harness could not find a monster map point.");
                    }

                    GD.Print($"[VakuuHarness] traveling to actual first monster coord={point.Point.coord}");
                    _travelTask = TravelAsync(map, point.Point.coord);
                    return;
                }

                if (_fightCommandSent && !_combatLogged)
                {
                    var combat = FindNodeByTypeName(root, "NCombatRoom");
                    if (combat != null)
                    {
                        _combatLogged = true;
                        _combatFrames = 0;
                        LogCombatHand();
                        GD.Print("[VakuuHarness] first combat room entered");
                    }
                }

                if (_combatLogged && !_combatChoiceConfirmed)
                {
                    var combatSelection = FindNode<NSimpleCardSelectScreen>(root);
                    if (combatSelection == null)
                    {
                        return;
                    }

                    var combatSelectedCards = typeof(NSimpleCardSelectScreen)
                        .GetField("_selectedCards", BindingFlags.Instance | BindingFlags.NonPublic)
                        ?.GetValue(combatSelection) as HashSet<CardModel>;
                    var combatCards = typeof(NSimpleCardSelectScreen)
                        .GetField("_cards", BindingFlags.Instance | BindingFlags.NonPublic)
                        ?.GetValue(combatSelection) as IReadOnlyList<CardModel>;
                    var combatConfirm = combatSelection.GetType().GetMethod(
                        "CheckIfSelectionComplete", BindingFlags.Instance | BindingFlags.NonPublic);
                    if (combatSelectedCards == null || combatCards == null || combatConfirm == null || combatCards.Count == 0)
                    {
                        throw new InvalidOperationException("Harness could not inspect Choices Paradox selection.");
                    }

                    combatSelectedCards.Add(combatCards[0]);
                    _combatChoiceConfirmed = true;
                    GD.Print($"[VakuuHarness] confirming Choices Paradox card={combatCards[0].Id.Entry}");
                    combatConfirm.Invoke(combatSelection, null);
                    return;
                }

                if (_combatLogged && !_endTurnCommandSent)
                {
                    _combatFrames++;
                    if (_combatFrames < CombatWaitFrames)
                    {
                        return;
                    }

                    LogCombatHand();
                    var player = LocalContext.GetMe(RunManager.Instance.DebugOnlyGetState());
                    if (player == null)
                    {
                        throw new InvalidOperationException("Harness could not find combat player to end turn.");
                    }
                    _endTurnCommandSent = true;
                    _combatFrames = 0;
                    GD.Print("[VakuuHarness] ending first player turn to test next turn");
                    PlayerCmd.EndTurn(player, false, null);
                    GD.Print("[VakuuHarness] player control returned; end-turn issued");
                    return;
                }

                if (_combatLogged && _endTurnCommandSent && !_winCommandSent)
                {
                    _combatFrames++;
                    if (_combatFrames < CombatWaitFrames)
                    {
                        return;
                    }

                    LogCombatHand();
                    GD.Print($"[VakuuHarness] first combat auto-play count={_autoPlayCount} cards={string.Join(",", AutoPlayedCards)}");
                    if (StartCommand("win"))
                    {
                        _winCommandSent = true;
                    }
                    return;
                }

                if (_winCommandSent && !_actCommandSent)
                {
                    if (!CommandCompleted())
                    {
                        return;
                    }

                    _winFrames++;
                    if (_winFrames < WinWaitFrames || CombatManager.Instance?.IsInProgress == true)
                    {
                        return;
                    }

                    if (StartCommand("act 3"))
                    {
                        _actCommandSent = true;
                    }
                    return;
                }

                if (_actCommandSent && !_finished)
                {
                    if (!CommandCompleted())
                    {
                        return;
                    }

                    _actFrames++;
                    if (_actFrames < ActWaitFrames)
                    {
                        return;
                    }

                    if (!_neowCommandSent)
                    {
                        if (NMapScreen.Instance?.IsOpen == true)
                        {
                            NMapScreen.Instance.Close(false);
                        }
                        if (StartCommand("ancient NEOW"))
                        {
                            _neowCommandSent = true;
                        }
                        return;
                    }

                    if (!CommandCompleted())
                    {
                        return;
                    }

                    var ancientLayout = FindNodeByTypeName(root, "NAncientEventLayout");
                    var dialogueLine = FindNodeByTypeName(root, "NAncientDialogueLine");
                    if (ancientLayout is not CanvasItem ancientCanvas
                        || dialogueLine is not CanvasItem dialogueCanvas
                        || !ancientCanvas.IsVisibleInTree()
                        || !dialogueCanvas.IsVisibleInTree())
                    {
                        return;
                    }

                    GD.Print("[VakuuHarness] Neow dialogue visible");
                    _finished = true;
                    LogAct3Result();
                    return;
                }

                var selection = FindNode<NDeckCardSelectScreen>(root);
                if (_selectionConfirmed || selection == null)
                {
                    return;
                }

                var selectedCards = typeof(NDeckCardSelectScreen)
                    .GetField("_selectedCards", BindingFlags.Instance | BindingFlags.NonPublic)
                    ?.GetValue(selection) as HashSet<CardModel>;
                var cards = typeof(NDeckCardSelectScreen)
                    .GetField("_cards", BindingFlags.Instance | BindingFlags.NonPublic)
                    ?.GetValue(selection) as IReadOnlyList<CardModel>;
                var confirm = selection.GetType().GetMethod(
                    "CheckIfSelectionComplete", BindingFlags.Instance | BindingFlags.NonPublic);
                if (selectedCards == null || cards == null || confirm == null || cards.Count < 3)
                {
                    throw new InvalidOperationException("Harness could not inspect the deck selection screen.");
                }

                foreach (var card in cards.Take(3))
                {
                    selectedCards.Add(card);
                }
                _selectionConfirmed = true;
                _needFight = true;
                GD.Print($"[VakuuHarness] confirming first 3 snapshot cards: {string.Join(", ", cards.Take(3).Select(c => c.Id.Entry))}");
                confirm.Invoke(selection, null);
                return;
            }

            var main = FindNode<NMainMenu>(root);
            if (!_openedSingleplayer && main != null)
            {
                _openedSingleplayer = true;
                GD.Print("[VakuuHarness] opening singleplayer submenu");
                main.OpenSingleplayerSubmenu();
                _frames = 0;
                return;
            }

            var singleplayer = FindNode<NSingleplayerSubmenu>(root);
            if (!_openedCharacterSelect && singleplayer != null && _frames >= 600)
            {
                _openedCharacterSelect = true;
                GD.Print("[VakuuHarness] opening character select");
                var openCharacter = singleplayer.GetType().GetMethod(
                    "OpenCharacterSelect", BindingFlags.Instance | BindingFlags.NonPublic)
                    ?? throw new MissingMethodException(singleplayer.GetType().FullName, "OpenCharacterSelect");
                openCharacter.Invoke(singleplayer, new object?[] { null });
                _frames = 0;
                return;
            }

            var characterSelect = FindNode<NCharacterSelectScreen>(root);
            if (characterSelect == null)
            {
                return;
            }

            var lobbyField = typeof(NCharacterSelectScreen).GetField(
                "_lobby", BindingFlags.Instance | BindingFlags.NonPublic);
            var lobby = lobbyField?.GetValue(characterSelect);
            if (lobby == null)
            {
                characterSelect.InitializeSingleplayer();
                _frames = 0;
                return;
            }

            var begin = lobby.GetType().GetMethod(
                "BeginRunLocally", BindingFlags.Instance | BindingFlags.NonPublic);
            if (begin == null)
            {
                throw new MissingMethodException(lobby.GetType().FullName, "BeginRunLocally");
            }

            _started = true;
            GD.Print("[VakuuHarness] starting singleplayer run through StartRunLobby.BeginRunLocally");
            begin.Invoke(lobby, new object?[] { "VAKUU-COMBAT-ACT3-TEST", new List<ModifierModel>() });
        }
        catch (Exception e)
        {
            _started = true;
            Fail(e.ToString());
        }
    }

    private static async Task ChooseOptionAsync(EventModel eventModel)
    {
        if (eventModel.Owner == null)
        {
            throw new InvalidOperationException("Vakuu event has no owner.");
        }

        await eventModel.CurrentOptions[0].Chosen();
    }

    private static Task TravelAsync(NMapScreen map, MapCoord coord)
    {
        return map.TravelToMapCoord(coord);
    }

    private static bool StartCommand(string command)
    {
        var result = new DevConsole(true).ProcessCommand(command);
        GD.Print($"[VakuuHarness] command='{command}' success={result.success} message={result.msg}");
        if (!result.success)
        {
            Fail($"command '{command}' failed: {result.msg}");
            return false;
        }

        _commandName = command;
        _commandTask = result.task ?? Task.CompletedTask;
        _commandCompletionLogged = false;
        return true;
    }

    private static bool CommandCompleted()
    {
        if (_commandTask == null || !TaskCompleted(_commandTask, $"command '{_commandName}'"))
        {
            return false;
        }

        if (!_commandCompletionLogged)
        {
            GD.Print($"[VakuuHarness] command task complete='{_commandName}'");
            _commandCompletionLogged = true;
        }
        return true;
    }

    private static bool TaskCompleted(Task task, string operation)
    {
        if (!task.IsCompleted)
        {
            return false;
        }
        if (task.IsCanceled)
        {
            Fail($"{operation} was cancelled");
            return false;
        }
        if (task.IsFaulted)
        {
            Fail($"{operation} failed: {task.Exception?.GetBaseException()}");
            return false;
        }
        return true;
    }

    private static void Fail(string message)
    {
        if (_failed)
        {
            return;
        }
        _failed = true;
        _finished = true;
        GD.PrintErr($"[VakuuHarness] failed: {message}");
    }

    private static int CurrentCombatTurn()
    {
        var player = LocalContext.GetMe(RunManager.Instance.DebugOnlyGetState());
        return player?.PlayerCombatState?.TurnNumber ?? -1;
    }

    private static bool LogStartingRelics()
    {
        var player = LocalContext.GetMe(RunManager.Instance.DebugOnlyGetState());
        if (player == null)
        {
            return false;
        }

        var ids = player.Relics.Select(relic => relic.Id.Entry).ToList();
        var vakuuIds = ids.Where(VakuuRelicIds.Contains).ToList();
        var signature = string.Join(",", ids.Order());
        if (signature != _lastStartingRelicSignature)
        {
            _lastStartingRelicSignature = signature;
            GD.Print($"[VakuuHarness] starting Vakuu relics={vakuuIds.Count} total relics={ids.Count} ids={string.Join(",", ids)}");
        }
        if (!VakuuRelicIds.SetEquals(vakuuIds))
        {
            return false;
        }

        var contract = player.Relics.First(relic => relic.Id.Entry == "VAKUU_CONTRACT");
        ValidateVakuuContractLocalization(contract);
        return true;
    }

    private static void ValidateVakuuContractLocalization(RelicModel contract)
    {
        var originalLanguage = LocManager.Instance.Language;
        var fallbackLanguage = LocManager.Languages.FirstOrDefault(
            language => language is not ("eng" or "zhs" or "zht"));
        if (fallbackLanguage == null)
        {
            throw new InvalidOperationException("No unsupported language was available to test the English localization fallback.");
        }

        var languages = new[] { "eng", "zhs", "zht", fallbackLanguage };
        try
        {
            foreach (var language in languages)
            {
                LocManager.Instance.SetLanguage(language);
                var title = contract.Title.GetRawText();
                var description = contract.DynamicDescription.GetRawText();
                var flavor = contract.Flavor.GetRawText();
                var expectedTitle = language switch
                {
                    "zht" => "瓦庫契約",
                    "zhs" => "瓦库契约",
                    _ => "Vakuu's Contract",
                };
                if (title != expectedTitle
                    || string.IsNullOrWhiteSpace(description)
                    || string.IsNullOrWhiteSpace(flavor))
                {
                    throw new InvalidOperationException($"VakuuContract localization did not resolve for language {language}.");
                }
            }
        }
        finally
        {
            if (LocManager.Instance.Language != originalLanguage)
            {
                LocManager.Instance.SetLanguage(originalLanguage);
            }
        }

        var titleAfterRestore = contract.Title.GetRawText();
        var descriptionAfterRestore = contract.DynamicDescription.GetRawText();
        var flavorAfterRestore = contract.Flavor.GetRawText();
        GD.Print($"[VakuuHarness] VakuuContract localization resolved title={titleAfterRestore} description={descriptionAfterRestore} flavor={flavorAfterRestore} languages={string.Join(",", languages)}");
    }

    private static void LogCombatHand()
    {
        var player = LocalContext.GetMe(RunManager.Instance.DebugOnlyGetState());
        if (player == null)
        {
            GD.PrintErr("[VakuuHarness] combat player unavailable");
            return;
        }

        var hand = PileTypeExtensions.GetPile(PileType.Hand, player);
        var cards = hand?.Cards.Select(card => $"{card.Id.Entry}:{card.CanPlay()}") ?? [];
        var relics = player.Relics.Select(relic => $"{relic.Id.Entry}:{relic.GetType().FullName}:melted={relic.IsMelted}");
        var hookRelics = player.RunState
            .IterateHookListeners(player.Creature.CombatState)
            .OfType<RelicModel>()
            .Select(relic => relic.Id.Entry);
        GD.Print($"[VakuuHarness] combat netId={LocalContext.NetId} hand={string.Join(",", cards)}");
        GD.Print($"[VakuuHarness] combat relics={string.Join(" | ", relics)} hookRelics={string.Join(",", hookRelics)}");
    }

    private static void LogAct3Result()
    {
        var state = RunManager.Instance.DebugOnlyGetState();
        var glory = ModelDb.Acts.First(act => act.Id.Entry == "GLORY");
        var ancients = glory.AllAncients.Select(ancient => ancient.Id.Entry).ToArray();
        var actIndex = typeof(RunState).GetProperty(nameof(RunState.CurrentActIndex))?.GetValue(state);
        GD.Print($"[VakuuHarness] act 3 result currentActIndex={actIndex} gloryAncients={string.Join(",", ancients)} containsVakuu={ancients.Contains("VAKUU")}");
        GD.Print($"[VakuuHarness] combat auto-phase turns={string.Join(",", AutoPhaseTurns)} auto-play turns={string.Join(",", AutoPlayTurns)}");
        GD.Print($"[VakuuHarness] FINAL firstCombatAutoPlayCount={_autoPlayCount} distinctAutoPlayTurns={string.Join(",", AutoPlayTurns.Distinct().Order())} thirdActVakuuExcluded={!ancients.Contains("VAKUU")}");
    }

    private static Node? FindNodeByTypeName(Node node, string typeName)
    {
        if (node.GetType().Name == typeName)
        {
            return node;
        }
        foreach (var child in node.GetChildren())
        {
            var result = FindNodeByTypeName(child, typeName);
            if (result != null)
            {
                return result;
            }
        }
        return null;
    }

    private static T? FindNode<T>(Node node) where T : Node
    {
        if (node is T match)
        {
            return match;
        }
        foreach (var child in node.GetChildren())
        {
            var result = FindNode<T>(child);
            if (result != null)
            {
                return result;
            }
        }
        return null;
    }

    private static void Collect(Node node, List<string> names, int depth)
    {
        if (depth > 8 || names.Count >= 100)
        {
            return;
        }
        names.Add($"{node.Name}:{node.GetType().Name}");
        foreach (var child in node.GetChildren())
        {
            Collect(child, names, depth + 1);
        }
    }
}
