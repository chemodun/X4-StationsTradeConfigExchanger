# Stations Trade Config Exchanger

Stations Trade Config Exchanger allows you to exchange the trade configuration from one station to another. It is useful when you want to have the same trade configuration for several stations.

## Features

- Transfer trade configuration between stations.
- Can work with production and trading stations.
- Allows selecting wares by groups: Resources, Intermediates, Products, Trade Wares.
- Allows apply the entire ware configuration or only selectable trade ware aspects: Storage allocation, Buy order, Sell order.
- Filters Station Two list to show only stations compatible with the Station One trade configuration.

## Limitations

- Can't work with stations contained the ships factory modules, i.e. with Shipyards and Wharfs.
- Identifies trading stations as stations with cargo bays and without production modules. I.e. if your defence platform has cargo modules - it's will be identified as trading station.

## Requirements

- `X4: Foundations` 7.60 or newer (tested on 7.60 and 8.00).
- `Mod Support APIs` by [SirNukes](https://next.nexusmods.com/profile/sirnukes?gameId=2659) to be installed and enabled. Version `1.93` and upper is required.
  - It is available via Steam - [SirNukes Mod Support APIs](https://steamcommunity.com/sharedfiles/filedetails/?id=2042901274)
  - Or via the Nexus Mods - [Mod Support APIs](https://www.nexusmods.com/x4foundations/mods/503)

## Caution

**Please, be aware that is first public release version of the Stations Trade Config Exchanger mod. Although it was tested in several scenarios, there may be some unforeseen issues or bugs.**

## Installation

You can download the latest version via Steam client - [Stations Trade Config Exchanger](https://steamcommunity.com/sharedfiles/filedetails/?id=)
Or you can do it via the Nexus Mods - [Stations Trade Config Exchanger](https://www.nexusmods.com/x4foundations/mods/1891)

## Usage

### How to call the Trade Config Exchanger UI

You can open the Trade Config Exchanger UI from the Stations Context Menu.

To do this, simply select a station on a `Map` or from `Property Owned` list, then right-click on it, and select `Trade Config Exchanger` from the context menu.

![Stations Trade Config Exchanger Context Menu Item](docs/images/select_from_context_menu.png)

### Trade Config Exchanger UI

The Trade Config Exchanger UI allows you to select the Station One and Station Two, and configure how the trade configuration will be exchanged between them.

![Trade Config Exchanger UI after selection from context menu](docs/images/initial_screen_for_production_station.png)

At the beginning only the Station One is selected, based on your previous selection. After selecting it, the Station Two selection will be enabled.

### Station Two selection

Only compatible stations will be shown in the Station Two list. It is determined based on the production configurations of the stations. It is made based on Intermediates and Products wares.

![Station Two selection for production station](docs/images/station_two_selection_for_production_station.png)

### Station Two selection for trading stations

When you open the Trade Config Exchanger UI from a trading station, the Station One will be preselected as the trading station, and the Station Two list will be filtered to show only compatible stations.

![Station Two selection for trading station](docs/images/station_two_selection_for_trade_station.png)

### Selecting what to exchange (clone)

After selecting both stations, you can choose what to exchange (clone) between them.

![Both Stations Selected](docs/images/screen_after_both_stations_selected.png)

You can choose to exchange (clone) the items with the different level of detail:

- Per Ware Group: Resources, Intermediates, Products, Trade Wares.

![Selected Resources Group of Wares](docs/images/selected_resources_group_of_wares.png)

- Per single ware.

![Selected Single Ware](docs/images/selected_single_whole_ware.png)

- Per ware trade configuration aspect: Storage Allocation, Buy Order, Sell Order.

![Selected Different Aspects in Different Wares](docs/images/selected_different_aspects_in_different_wares.png)

### Executing the exchange (clone)

After selecting what to exchange (clone), you should select a confirmation checkbox, `Confirm before proceeding with cloning`, and then click appropriate button:

- `Clone >` to clone the trade configuration from the Station One to the Station Two.
- `< Clone` to clone the trade configuration from the Station Two to the Station One.

#### Cloning example from Station One to Two Station

![Example from One to Two. Before cloning](docs/images/from_one_to_two_before_cloning.png)
![Example from One to Two. After cloning](docs/images/from_one_to_two_after_cloning.png)

#### Cloning example from Station Two to One Station

![Example from Two to One. Before cloning](docs/images/from_two_to_one_before_cloning.png)
![Example from Two to One. After cloning](docs/images/from_two_to_one_after_cloning.png)

#### Trade Stations "Full" Cloning Examples

##### Cloning from configured to "empty" trade station

![Empty station before cloning](docs/images/empty_station_before.png)
![Full to empty before page one](docs/images/full_to_empty_before_page_one.png)
![Full to empty before page two](docs/images/full_to_empty_before_page_two.png)
![Full to empty before page two ready](docs/images/full_to_empty_before_page_two_ready.png)
![Full to empty after page two](docs/images/full_to_empty_after_page_two.png)
![Empty station after cloning](docs/images/empty_station_after.png)

##### Cloning from "empty" to configured trade station

In this example will be cloned all "empty" wares except first and last wares that will be left unchanged.

![Empty to full before page one](docs/images/empty_to_full_before_page_one.png)
![Empty to full before page two](docs/images/empty_to_full_before_page_two.png)
![Empty to full after](docs/images/empty_to_full_after.png)
![Full station after cloning](docs/images/full_station_after.png)

## Video

[Video demonstration of the Stations Trade Config Exchanger. Version 1.00](https://www.youtube.com/watch?v=cWfU4Az8yAo)

## Credits

- Author: Chem O`Dun, on [Nexus Mods](https://next.nexusmods.com/profile/ChemODun/mods?gameId=2659) and [Steam Workshop](https://steamcommunity.com/id/chemodun/myworkshopfiles/?appid=392160)
- *"X4: Foundations"* is a trademark of [Egosoft](https://www.egosoft.com).

## Acknowledgements

- [EGOSOFT](https://www.egosoft.com) — for the X series.
- [SirNukes](https://next.nexusmods.com/profile/sirnukes?gameId=2659) — for the Mod Support APIs that power the UI hooks.
- [Forleyor](https://next.nexusmods.com/profile/Forleyor?gameId=2659) — for his constant help with understanding the UI modding!

## Changelog

### [1.00] - 2025-11-23

- Added
  - Initial public version
