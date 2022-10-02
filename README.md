# Modern Simple Krist Shop

This is a simple Krist shop that supports many different wallets and configurations.

## Configuration

Setup for the shop is split between two serialized table files

### config

This file is where you'll configure the settings for the shop.

Required settings
* `address` - return address, matches `privateKey` and `name` (if provided).
* `privateKey` - private key for `address`, and where returns are sent from.
* `inventories` - table of inventory peripheral names.
* `monitor` - peripheral name of monitor to display listings on.
* `shopName` - friendly name to display on the monitor.
* `contactName` - a recognizable name for the shop owner, as who to contact over issues with the shop.
* `kristEndpoint` - the endpoint for krist to use
* `theme` - a table of theme colors
* `sounds` - a table of sound effects

Optional settings
* `name` - default name for listings to use, can be overridden
* `speaker` - peripheral name for an attached speaker, used for sound effects

### listings

This file is where you'll configure the items you're selling in your shop

It is a serialized table of listing entries, each entry contains the following values:

* `label` - friendly label displayed on the monitor
* `id` - internal item ID for this item i.e. `minecraft:cobblestone`
* `price` - price in KST / Item for this listing
* `address` - address this listing should listen to`*`
* `name` - name this listing should listen to`*`
* `metaname` - metaname this listing should listen to`*`

`*` These follow a set of rules for inheriting the defaults. If the entry is set to `nil`, it will inherit the default setting from `config.lua` (if applicable).
If the entry is set to the empty string `""`, it will overwrite the default by removing this option. Otherwise this entry will be used as the setting for the field.

#### Example listings

Listing iron ingots for sale at the default address and name, but custom metaname
```lua
  {
    label = "Iron", -- Friendly label
    id = "minecraft:iron_ingot", -- Name of internal item name
    price = 0.25, -- price in KST / Item
    address = nil, -- address for overriding defaultAddress
    name = nil, -- space for overriding name for this item
    metaname = "iron", -- metaname like "iron" of iron@aname.kst 
  },
```

Listing iron ingots for sale at a custom address, with no name
```lua
  {
    label = "Iron",
    id = "minecraft:iron_ingot",
    price = 0.2,
    address = "insertKristAddress",
    name = "",
    metaname = "",
  }
```

## Behavior

The shop will display the name of your shop and who operates the shop at the top of the monitor specified.

Underneath this will be listings, alternating in color, each listing will follow this format:
```
Count Name        Sendto         KST/Item
100   Cobblestone an@address.kst 0.02
```

When you send krist to a given address, the shop will handle the transaction by:
* Calculating the amount of items to dispense by `floor(amountPaid / price)`
  * Attempt to dispense these items, updates `itemsDispensed`
* Calculating the refund to give via `floor(amountPaid - (itemsDispensed * price))`
  * If this amount is > 0 then issue a transaction from the configured `address` (and name, if supplied), if the transaction fails the shop will throw an error

### Shop Errors
This shop will error safely.
* The websocket will be closed
* A warning will be displayed on the monitor with the following information:
  * Github Link
  * Shop Owner
  * Shop Name
  * Error

# Krist Transaction Websocket Library

This is a library to make transaction tracking easy!

## Quickstart

Require the library `local ktwsl = require("ktwsl")`

Create a krist manager object by calling the function returned (passing in the desired endpoint and your privatekey), `local krist = ktwsl("https://krist.dev", privatekey)`

Add any addresses you want to listen for transactions from via `krist.subscribeAddress("anAddressOrNameHere")`. This supports addresses AND names, so `aname@alt.kst` is as valid as `kziwwr5hm9`. You can subscribe or unsubscribe from addresses at any time, including while the krist manager is running, without any additional effort.

Once you want your krist manager to start throwing events for transactions simply call `krist.start()`

There are two events to listen for
* `"krist_transaction", toAddress, fromAddress, value, transactionTable`
  * This fires whenever a transaction to an address you've subscribed to occurs.
  * Both given addresses (`toAddress` and `fromAddress`) will be names if applicable, otherwise just a base krist address.
* `"krist_stop", errorReason`
  * This fires whenever the websocket / handler gives any errors. Once this event fires the websocket is disconnected. You can either error, or handle it gracefully and restart the krist manager with `krist.start()`


## Some notes

* Only one krist listener can be active at a time, if you call `krist.start()` on a different krist object, the first one will be removed from `redrun`, and therefor stop listening to websocket messages.

* When exiting your program try to clean up by calling `krist.stop()`, this will stop any redrun tasks executing and remove them from the courotine manager.

## Example
```lua
local krist = require("ktwsl")("https://krist.dev", "aprivatekeylol")
krist.subscribeAddress("iron@alt.kst")
krist.start()

while true do
  local event, to, from, value, transaction = os.pullEventRaw()
  if event == "terminate" then
    krist.stop()
    error("Terminated")
  elseif event == "krist_stop" then
    krist.stop()
    error("Websocket died: "..to)
  elseif event == "krist_transaction" then
    print(value.."kst was sent to "..to.." from "..from)
  end
end
```