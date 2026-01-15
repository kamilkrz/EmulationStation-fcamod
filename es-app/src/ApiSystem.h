#ifndef API_SYSTEM
#define API_SYSTEM

#include <string>
#include <functional>
#include <vector>
#include "platform.h"

class Window;

namespace UpdateState
{
	enum State
	{
		NO_UPDATE,
		UPDATER_RUNNING,
		UPDATE_READY
	};
}

struct ThemeDownloadInfo
{
	bool installed;
	std::string name;
	std::string url;
};

class ApiSystem
{
public:
	static UpdateState::State state;

	static std::pair<std::string, int> updateSystem(const std::function<void(const std::string)>& func = nullptr);
	static std::string checkUpdateVersion();
	static void startUpdate(Window* c);

	static std::vector<ThemeDownloadInfo> getThemesList();
	static std::pair<std::string, int> installTheme(std::string themeName, const std::function<void(const std::string)>& func = nullptr);

    static ApiSystem* getInstance();
	virtual void deinit() { };

	int	getBrightnessLevel();
	bool	getBrighness(int& value);
	void	setBrighness(int value);
    BatteryInformation getBatteryInformation(bool summary = true);

	// Network/WiFi functions
	virtual std::string getIpAddress();
	virtual bool ping();
	virtual std::string getWifiStatus();
	virtual std::string getConnectedSSID();
	virtual std::vector<std::string> getWifiNetworks(bool scan = false);
	virtual std::vector<std::string> getSavedWifiConnections();
	virtual bool isWifiConnectionSaved(const std::string& ssid);
	virtual bool enableWifi();
	virtual bool connectWifi(const std::string& ssid, const std::string& key);
	virtual bool connectSavedWifi(const std::string& connectionName);
	virtual bool disableWifi();

protected:
    static ApiSystem* instance;
};

#endif
