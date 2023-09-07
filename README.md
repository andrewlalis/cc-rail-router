# CC-Rail-Router

A system for using Computercraft to control minecart junctions and routing. It works by having a traveling portable computer send out messages as it's traveling, so that nearby managed switches are set automatically.

The portable computer, usually held by the traveling player, will send out a message containing its route as a list of strings, like so:
```lua
{ "A", "C", "D", "V" }
```

The switch controller will reply then look for any pairs of branch segments that it has control of, and will switch them accordingly. So suppose we have a switch that connects line `C` to line `D`, then upon receiving the above message, it'll change its signal outputs to route trains accordingly from `C` to `D`.

With this design, the switch controller and portable computer are completely stateless, and no two-way communication is needed.
