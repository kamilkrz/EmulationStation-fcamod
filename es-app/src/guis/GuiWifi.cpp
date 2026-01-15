#include "guis/GuiWifi.h"
#include "guis/GuiTextEditPopupKeyboard.h"
#include "Window.h"
#include "Log.h"
#include "Settings.h"
#include "ApiSystem.h"
#include "renderers/Renderer.h"
#include "math/Misc.h"
#include <thread>
#include <algorithm>

GuiWifi::GuiWifi(Window* window, const std::string title, std::string data, const std::function<void(std::string)>& onsave)
	: GuiComponent(window), mMenu(window, title.c_str())
{
	mTitle = title;
	mInitialData = data;
	mSaveFunction = onsave;
	mWaitingLoad = false;

	addChild(&mMenu);

	// Scan for networks synchronously on construction
	std::vector<std::string> ssids = ApiSystem::getInstance()->getWifiNetworks(true);

	// Get list of saved connections for marking
	std::vector<std::string> savedConnections = ApiSystem::getInstance()->getSavedWifiConnections();

	if (ssids.empty())
	{
		mMenu.addEntry(_("NO WIFI NETWORKS FOUND"), false, nullptr);
	}
	else
	{
		for (const auto& ssid : ssids)
		{
			bool isConnected = (ssid == mInitialData);
			bool isSaved = std::find(savedConnections.begin(), savedConnections.end(), ssid) != savedConnections.end();
			
			std::string displayName = ssid;
			if (isConnected)
				displayName = ssid + " *";
			else if (isSaved)
				displayName = ssid + " [+]";

			mMenu.addEntry(displayName, false, [this, ssid]() { onNetworkSelected(ssid); });
		}
	}

	mMenu.addButton(_("REFRESH"), "refresh", [this] { onRefresh(); });
	mMenu.addButton(_("MANUAL INPUT"), "manual input", [this] { onManualInput(); });
	mMenu.addButton(_("BACK"), "back", [this] { delete this; });

	float width = Math::min(Renderer::getScreenWidth() * 0.9f, 400.0f);
	mMenu.setSize(width, mMenu.getSize().y());
	mMenu.setPosition((Renderer::getScreenWidth() - mMenu.getSize().x()) / 2,
	                  (Renderer::getScreenHeight() - mMenu.getSize().y()) / 2);
}

GuiWifi::~GuiWifi()
{
}

void GuiWifi::onNetworkSelected(const std::string& ssid)
{
	if (mWaitingLoad)
		return;

	Window* window = mWindow;

	// Check if this connection is already saved
	bool isSaved = ApiSystem::getInstance()->isWifiConnectionSaved(ssid);

	if (isSaved)
	{
		// Connection is saved, connect directly without password prompt
		window->displayNotificationMessage(_("CONNECTING TO") + " " + ssid + "...");
		
		std::function<void(std::string)> saveFunc = mSaveFunction;
		
		// Run connection in separate thread to avoid blocking UI
		std::thread([window, ssid, saveFunc]()
		{
			if (ApiSystem::getInstance()->connectSavedWifi(ssid))
			{
				window->displayNotificationMessage(_("CONNECTED TO") + " " + ssid);
				// Call callback to refresh menu
				if (saveFunc)
					saveFunc(ssid);
			}
			else
				window->displayNotificationMessage(_("FAILED TO CONNECT TO") + " " + ssid);
		}).detach();
	}
	else
	{
		// Connection is not saved, prompt for password
		std::function<void(std::string)> saveFunc = mSaveFunction;
		
		mWindow->pushGui(new GuiTextEditPopupKeyboard(mWindow, _("WIFI PASSWORD"), "",
			[window, ssid, saveFunc](const std::string& password)
			{
				window->displayNotificationMessage(_("CONNECTING TO") + " " + ssid + "...");
				
				// Run connection in separate thread to avoid blocking UI
				std::thread([window, ssid, password, saveFunc]()
				{
					if (ApiSystem::getInstance()->connectWifi(ssid, password))
					{
						window->displayNotificationMessage(_("CONNECTED TO") + " " + ssid);
						// Call callback to refresh menu
						if (saveFunc)
							saveFunc(ssid);
					}
					else
						window->displayNotificationMessage(_("FAILED TO CONNECT TO") + " " + ssid);
				}).detach();
			}, false));
	}

	delete this;
}

void GuiWifi::onManualInput()
{
	if (mWaitingLoad)
		return;

	Window* window = mWindow;
	std::function<void(std::string)> saveFunc = mSaveFunction;

	// First prompt for SSID
	window->pushGui(new GuiTextEditPopupKeyboard(window, _("ENTER WIFI SSID"), "",
		[window, saveFunc](const std::string& ssid)
		{
			if (ssid.empty())
				return;

			// Then prompt for password
			window->pushGui(new GuiTextEditPopupKeyboard(window, _("WIFI PASSWORD"), "",
				[window, ssid, saveFunc](const std::string& password)
				{
					window->displayNotificationMessage(_("CONNECTING TO") + " " + ssid + "...");
					
					// Run connection in separate thread to avoid blocking UI
					std::thread([window, ssid, password, saveFunc]()
					{
						if (ApiSystem::getInstance()->connectWifi(ssid, password))
						{
							window->displayNotificationMessage(_("CONNECTED TO") + " " + ssid);
							// Call callback to refresh menu
							if (saveFunc)
								saveFunc(ssid);
						}
						else
							window->displayNotificationMessage(_("FAILED TO CONNECT TO") + " " + ssid);
					}).detach();
				}, false));
		}, false));

	delete this;
}

void GuiWifi::onSave(const std::string& value)
{
	if (mWaitingLoad)
		return;

	if (mSaveFunction)
		mSaveFunction(value);

	delete this;
}

bool GuiWifi::input(InputConfig* config, Input input)
{
	if (GuiComponent::input(config, input))
		return true;

	if (input.value != 0 && config->isMappedTo(BUTTON_BACK, input))
	{
		if (!mWaitingLoad)
			delete this;

		return true;
	}

	return false;
}

std::vector<HelpPrompt> GuiWifi::getHelpPrompts()
{
	std::vector<HelpPrompt> prompts = mMenu.getHelpPrompts();
	prompts.push_back(HelpPrompt(BUTTON_BACK, _("BACK")));
	return prompts;
}

void GuiWifi::onRefresh()
{
	if (mWaitingLoad)
		return;

	// Close this GUI and open a new one to refresh the list
	Window* window = mWindow;
	std::string title = mTitle;
	std::string initialData = mInitialData;
	std::function<void(std::string)> saveFunc = mSaveFunction;

	delete this;

	// Create a new GuiWifi which will scan again
	window->pushGui(new GuiWifi(window, title, initialData, saveFunc));
}