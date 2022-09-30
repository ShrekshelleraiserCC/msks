# Modern Simple Krist Shop

This is a simple Krist shop that supports many different wallets and configurations.

## Configuration

Setup for the shop is split between two serialized table files

### config.lua

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

### listings.lua

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
x100  Cobblestone an@address.kst 0.02kst
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