> [!WARNING]
> This version of KYBER is not up to date. Be on the lookout for the [KYBER V2](https://uplink.kyber.gg/news/features-overview/) update, which has been under private development, with a whole host of new and improved features.

<h1 align="center"><img src="https://kyber.gg/logo2.svg" width="30rem"> Kyber</h1>

<h4 align="center">Kyber is an Open-Source Private Server tool for STAR WARS™ Battlefront™ II (2017).</h4>
<br>
<p align="center">
  <a href="https://twitter.com/BattleDashBR"><img src="https://img.shields.io/badge/Twitter-@BattleDashBR-1da1f2.svg?logo=twitter"></a>
  <a href="https://discord.gg/kyber">
      <img src="https://img.shields.io/discord/305338604316655616.svg?label=Discord&logo=discord&color=778cd4">
  </a>
  
</p>

------

A hosted version of Kyber is available at [kyber.gg](https://kyber.gg), where I operate proxies for server data that alleviate the issue of port forwarding and IP security.

What's done:
* Server starting
* Networking
* Direct proxy support
* NAT Punch-Through system
* In-Game server browser
* Per-player team swapping
* Player kicking/moderation
* Optimal proxy detection

What isn't done:
* Built-in mod verification (currently handled at the proxy level, meaning it's unavailable if you direct-connect)
* Kick messages (currently if you are kicked by the server admin you just get sent back to the menu with no indication of why)
* UX/UI Styling (WIP)
* Player banning
* Database handling at the proxy level

If you want to use Kyber purely without a proxy (port forwarding and having people connect to your IP), the rewrite (this) is completely usable for that, feel free to build Kyber and inject it with the new launcher (/Launcher, will need a few modifications to run your own dll).

**Stars and PRs are welcome!**

## Credits

Kyber utilizes the following open-source projects:

- [MinHook](https://github.com/TsudaKageyu/minhook)
- [ImGUI](https://github.com/ocornut/imgui)
- [GLFW](https://glfw.org)
- [cpp-httplib](https://github.com/yhirose/cpp-httplib)
- [openssl](https://openssl.org)
- [executors](https://github.com/chriskohlhoff/executors)
- [nlohmann-json](https://github.com/nlohmann/json)
