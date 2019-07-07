---
title: "Injecting Agent Names in Elixir Tests"
date: 2016-10-13 15:38 UTC
---


> This post is one in a series about building a collaborative music app in Elixir and Elm called [Loops With Friends]. If you'd like to catch up, visit the [first post] in the series to learn all about it!

We saw [previously] in this series how to leverage an Elixir agent as a stateful representation of our collection of jams at any given time. One gotcha that I ran into as I was testing the balancer was that its tests would fail when I ran the full test suite, but not when I ran only the tests for the balancer module. After digging up [a thread post by José Valim][Agent naming], I realized that the issue was due to both the unit and integration-level tests using the same balancer process. I was able to fix it by injecting an agent name into the `start_link` function of the [`JamBalancer`].

~~~ elixir
# lib/loops_with_friends/jam_balancer.ex
defmodule LoopsWithFriends.JamBalancer do
  # ...

  @name __MODULE__

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)

    Agent.start_link(fn -> JamCollection.new(opts) end, opts)
  end

  # ...
end
~~~

This allows us to pass in the name of our balancer's test module as an option in its [unit test][JamBalancer.ServerTest].

~~~ elixir
# test/lib/loops_with_friends/jam_balancer_test.exs
defmodule LoopsWithFriends.JamBalancerTest do
  # ...

  @name __MODULE__

  describe "`start_link`" do
    test "starts a new jam collection" do
      result = JamBalancer.start_link(name: @name)

      assert {:ok, _pid} = result

  # ...
end
~~~

Outside of this unit test, when a balancer worker is started by our supervision tree in any environment, the agent is passed the name of the `JamBalancer` module as defaulted above. This technique allows us to keep different tests from using the same stateful process, and thus keep them from interfering with each other.

This use of [dependency injection] also embodies the good testing practice of treating our tests as first-class clients of our production code. In this case, if our code needs some context from the client, we shouldn't be afraid to inject that context, whether the client is either more production code, or a test. However, since everything is a trade-off, this is only a good practice so long as passing context doesn't lead us to overly couple our code with tight dependencies.

In the [next post], we'll look at the difference between stubs and mocks in Elixir, and get some direction on their use by the language's creator.


[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[previously]: ./2016-10-07-talk-to-my-elixir-agent.html
[Agent naming]: https://groups.google.com/d/msg/elixir-lang-talk/TYBK6C7xHdg/Fv5o_CKvlSgJ
[`JamBalancer`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/server.ex
[JamBalancer.ServerTest]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/jam_balancer/server_test.exs
[dependency injection]: https://en.wikipedia.org/wiki/Dependency_injection
[next post]: ./2016-10-14-using-stubs-to-isolate-elixir-tests.html
