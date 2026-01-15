#pragma once

#include "GuiComponent.h"
#include "components/MenuComponent.h"

#include <functional>
#include <vector>
#include <string>

class GuiWifi : public GuiComponent
{
public:
	GuiWifi(Window* window, const std::string title, std::string data, const std::function<void(std::string)>& onsave);
	~GuiWifi();
	
	bool input(InputConfig* config, Input input) override;
	virtual std::vector<HelpPrompt> getHelpPrompts() override;

private:
	void onSave(const std::string& value);
	void onNetworkSelected(const std::string& ssid);
	void onManualInput();
	void onRefresh();

	MenuComponent mMenu;

	std::string mTitle;
	std::string mInitialData;

	std::function<void(std::string)> mSaveFunction;

	bool mWaitingLoad;
};