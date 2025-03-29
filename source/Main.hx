package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.events.Event;
#if mobile
import mobile.CopyState;
#end

using StringTools;

#if linux
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('
	#define GAMEMODE_AUTO
')
#end

#if NO_W11_CORNERS
@:cppFileCode('
	#include <windows.h>
	#include <dwmapi.h>

	#pragma comment(lib, "Dwmapi")
')
#end
class Main extends Sprite
{
	// These are taken from Funkin' 0.3.2
	public static var VERSION(get, never):String;
	public static final VERSION_SUFFIX:String = #if !PUBLIC_BUILD ' DEV' #else '' #end;
	/*
	public static final GIT_BRANCH:String = funkin.util.macro.GitCommit.getGitBranch();
	public static final GIT_HASH:String = funkin.util.macro.GitCommit.getGitCommitHash();
	public static final GIT_HAS_LOCAL_CHANGES:Bool = funkin.util.macro.GitCommit.getGitHasLocalChanges();
	*/

	public static final MIN_FRAMERATE:Int = 60;
	public static final MAX_FRAMERATE:Int = 360;

	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var focused:Bool = true; // Whether the game is currently focused or not.
	public static var fpsVar:FPSDisplay;

	public static var instance:Main;

	/*
	#if !PUBLIC_BUILD
	static function get_VERSION():String
	{
	  return 'v${FlxG.stage.application.meta.get('version')} (${GIT_BRANCH} : ${GIT_HASH}${GIT_HAS_LOCAL_CHANGES ? ' : MODIFIED' : ''})' + VERSION_SUFFIX;
	}
	#else
	*/
	static function get_VERSION():String
	{
	  return 'v${FlxG.stage.application.meta.get('version')}' + VERSION_SUFFIX;
	}
	//#end

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
		#if cpp
		cpp.NativeGc.enable(true);
		#elseif hl
		hl.Gc.enable(true);
		#end
	}

	public function new()
	{
		instance = this;

		#if mobile
		#if android
		StorageUtil.requestPermissions();
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end

		CrashHandler.init();

		#if windows
		@:functionCode("
		#include <windows.h>
		#include <winuser.h>
		setProcessDPIAware() // allows for more crisp visuals
		DisableProcessWindowsGhosting() // lets you move the window and such if it's not responding
		")
		#end
		
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	#if NO_W11_CORNERS
	@:functionCode('
		HWND hwnd = GetActiveWindow();
		const DWM_WINDOW_CORNER_PREFERENCE corner_preference = DWMWCP_DONOTROUND;
		DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner_preference, sizeof(corner_preference));
	')
	#end
	private function setupGame():Void
	{
		ClientPrefs.loadDefaultKeys();
		var game:FlxGame = new FlxGame(gameWidth, gameHeight, #if (mobile && MODS_ALLOWED) !CopyState.checkExistingFiles() ? CopyState : #end initialState, framerate, framerate, skipSplash, startFullscreen);

#if SOUNDTRAY
		// FlxG.game._customSoundTray wants just the class, it calls new from
		// create() in there, which gets called when it's added to stage
		// which is why it needs to be added before addChild(game) here
		@:privateAccess
		game._customSoundTray = funkin.ui.options.FunkinSoundTray;
#end

		addChild(game);

		fpsVar = new FPSDisplay(10, 3, 0xFFFFFF);
		#if !mobile
		addChild(fpsVar);
		#else
		FlxG.game.addChild(fpsVar);
		#end
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.showFPS;
		}

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if mobile
		lime.system.System.allowScreenTimeout = ClientPrefs.screensaver;
		#if android
		FlxG.android.preventDefaultKeys = [BACK]; 
		#end
		#end

		FlxG.signals.focusGained.add(function() {
			focused = true;
		});
		FlxG.signals.focusLost.add(function() {
			focused = false;
		});		
	}
}
