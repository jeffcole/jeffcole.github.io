---
title: "Using Stubs to Isolate Elixir Tests"
date: 2016-10-14 15:38 UTC
---


> This post is one in a series about building a collaborative music app in Elixir and Elm called [Loops With Friends]. If you'd like to catch up, visit the [first post] in the series to learn all about it!

You may have noticed in the previous posts in this series that the module names in the source links sometimes differ slightly from those shown in the posts' code listings. It's time to address why that is, via a discussion of isolated testing.

If you come from an object-oriented programming background, you may have had difficult experiences related to testing objects alongside their dependencies. When objects are tightly coupled, changes to one object can cause the tests for other objects to fail. This can result in a painful cycle of needing to change many different tests whenever a change to a single object is required.

The same scenario is possible in the functional world — the only difference is that we have modules and functions instead of objects and methods. The solution is to test and develop our application components in isolation as much as possible, while being sure to test the integration of these components separately. The [test pyramid] guides us in the direction of writing more focused, isolated, and fast unit tests, than interdependent and slower integration tests.

José Valim wrote an excellent post called [Mocks and Explicit Contracts] on how we can introduce new modules into our applications for the purposes of clarifying our code's responsibilities and isolating our tests.

> #### <a name="you-put-a-mock-in-my-stub"></a> You put a mock in my stub!
> José's use of the term "mock" deviates a bit from Martin Fowler's [delineation][Mocks Aren't Stubs] of the differences between "mocks" and "stubs," in that to me, his usage appears closer to what Martin refers to a "stub." I find Martin's breakdown helpful, so although José calls them "mocks," I'll refer to these entities as "stubs."

In our application, we can use José's technique to isolate the `JamChannelTest` from the implementation of the `JamBalancer`, a module upon which the channel depends. First, we'll place our balancer implementation in a submodule called [`JamBalancer.Server`] (so named as an allusion to the fact that our balancer's `Agent` is a `GenServer` under the covers). Then we'll create another module, [`JamBalancer.Stub`], where we'll put the code that we want our [`JamChannelTest`] to run whenever it needs balancer functionality.

For example, here's the stub code for the `jam_capacity?` function. We're pattern matching on particular argument values for the `jam_id`, so that we can test what happens in the channel when the balancer indicates that a jam is full.

~~~ elixir
# lib/loops_with_friends/jam_balancer/stub.ex
defmodule LoopsWithFriends.JamBalancer.Stub do
  # ...

  def jam_capacity?(_agent \\ @name, jam_id)
  def jam_capacity?(_agent, "jam-1"), do: true
  def jam_capacity?(_agent, "full-jam"), do: false

  # ...
end
~~~

The next thing we need to do is tell our application when to use our `Server` and when to use our `Stub`. We accomplish this by setting the `Server` as the default in [`config.exs`], so that it will be used in both the production and development environments.

~~~ elixir
# config/config.exs
# ...

config :loops_with_friends, :jam_balancer,
  LoopsWithFriends.JamBalancer.Server

# ...
~~~

Then, we tell the test environment to use the `Stub` in [`test.exs`].

~~~ elixir
# config/test.exs
# ...

config :loops_with_friends, :jam_balancer,
  LoopsWithFriends.JamBalancer.Stub

# ...
~~~

Finally, we instruct the [`JamChannel`] to load the proper balancer for the current environment into a module attribute, rather than reference a module name directly.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  @jam_balancer Application.get_env(
    :loops_with_friends,
    :jam_balancer
  )

  def join("jams:" <> jam_id, _params, socket) do
    if @jam_balancer.jam_capacity?(jam_id) do

  # ...
~~~

Now the channel will use the `Server` in production and development, while it will use the `Stub` in the test environment.

When our channel tests don't run any of our actual balancer code, they are isolated from changes to the balancer. This makes our tests more resilient to change, and therefore less brittle. Testing in this style can also lead you to naturally design modules and functions that are less coupled, resulting in an application that is easier to understand in pieces, and more pleasant to work on.

This technique was also useful when testing the balancer in isolation from the jam collection. I created a [`JamCollection.Stub`] module for use in the test environment, and placed the collection implementation in the [`JamCollection.Collection`] module.

Additionally, I followed José's example of making the contracts for balancers and collections explicit by using [Elixir behaviours], as seen in the [`JamCollection`] module.

There's another technique we can use to help mirror the decoupling that we've built into our production code in our tests — and we'll explore it in the [next post].


[Loops With Friends]: http://loopswithfriends.com/
[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[test pyramid]: http://martinfowler.com/bliki/TestPyramid.html
[Mocks and Explicit Contracts]: http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/
[Mocks Aren't Stubs]: http://martinfowler.com/articles/mocksArentStubs.html
[`JamBalancer.Server`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/server.ex
[`JamBalancer.Stub`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/stub.ex
[`JamChannelTest`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/jam_channel_test.exs
[`config.exs`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/config/config.exs#L29
[`test.exs`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/config/test.exs#L19
[`JamChannel`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/jam_channel.ex
[`JamCollection.Stub`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/stub.ex
[`JamCollection.Collection`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/collection.ex
[Elixir behaviours]: http://elixir-lang.org/getting-started/typespecs-and-behaviours.html#behaviours
[`JamCollection`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection.ex
[next post]: ./2016-10-15-testing-function-delegation-in-elixir.html
