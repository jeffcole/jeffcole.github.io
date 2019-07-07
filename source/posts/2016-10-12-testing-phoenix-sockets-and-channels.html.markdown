---
title: "Testing Phoenix Sockets and Channels"
date: 2016-10-12 15:38 UTC
---


> This post is one in a series about building a collaborative music app in Elixir and Elm called [Loops With Friends]. If you'd like to catch up, visit the [first post] in the series to learn all about it!

In the first post of this series we introduced the [Loops With Friends] app, and implemented [channel joining][first post] with Phoenix. Next we looked at [presence tracking, loop cycling, and event broadcasting]. Then we added [jam balancing] by leveraging an Elixir agent, and fixed a [race condition] in our channel joining process.

The next few posts will look at how the functional nature of Elixir makes applications written in it a joy to test. Elixir ships with the unit testing framework [ExUnit], which provides great testing support out of the box. We'll start with a brief look at testing Phoenix's abstractions around sockets and channels, and then move on to some techniques for building and maintaining a healthy test suite in Elixir.

## Making use of `ChannelTest`

Along with the code to support channel implementation, Phoenix also ships with code to make testing sockets and channels straightforward. This code lives in the `Phoenix.ChannelTest` module. The way that we take advantage of it is to `use` it in a module of our own, and then use *that* module in our actual test module. Note that this process is analogous to [how we implemented presence].

Specifically, we `use Phoenix.ChannelTest` in our `LoopsWithFriends` submodule `ChannelCase`, and then `use LoopsWithFriends.ChannelCase` in both of our `UserSocketTest` and `JamChannelTest` modules. Once we've done so, we have access to all of the functions and macros that [`Phoenix.ChannelTest`] provides. For instance, in [`UserSocketTest`], we use the `connect` macro to initialize a socket that we can then assert against.

~~~ elixir
# test/channels/user_socket_test.exs
defmodule LoopsWithFriends.UserSocketTest do
  use LoopsWithFriends.ChannelCase, async: true

  alias LoopsWithFriends.UserSocket

  test "`connect` assigns a UUID" do
    assert {:ok, socket} = connect(UserSocket, %{})

    # Ensure a valid UUID
    assert UUID.info!(socket.assigns.user_id)
  end
end
~~~

> The `async: true` on the `use` line lets ExUnit know that the tests in this module are safe to run asynchronously, which is a huge workflow boon for anyone familiar with slow test suites.

The tests in [`JamChannelTest`] similarly take advantage of Phoenix test functions and macros such as `subscribe_and_join`, `push`, `assert_push`, `refute_push`, and `assert_broadcast`.

~~~ elixir
# test/channels/jam_channel_test.exs
defmodule LoopsWithFriends.JamChannelTest do
  use LoopsWithFriends.ChannelCase, async: true

  setup do
    {:ok, socket} = connect(LoopsWithFriends.UserSocket, %{})

    {:ok, socket: socket}
  end

  describe "`join`" do
    test "replies with a `user_id`", %{socket: socket} do
      {:ok, reply, _socket} =
        subscribe_and_join(socket, "jams:jam-1", %{})

      assert %{user_id: user_id} = reply
      assert user_id
    end

    test "assigns the `jam_id`", %{socket: socket} do
      socket = subscribe_and_join!(socket, "jams:jam-1", %{})

      assert socket.assigns.jam_id == "jam-1"
    end

    test "pushes presence state", %{socket: socket} do
      {:ok, _reply, _socket} =
        subscribe_and_join(socket, "jams:jam-1", %{})

      assert_push "presence_state", %{}
    end
  end

  # ...
end
~~~

These conveniences make it easy to hook into the lifecycle of our channel and verify its behavior. Check out the [`JamChannelTest source`][`JamChannelTest`] to see the module tested in its entirety, including test cases covering a full jam and event broadcasting.

In the [next post] we'll move on to testing the components of our application that make it unique.


[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[jam balancing]: ./2016-10-07-talk-to-my-elixir-agent.html
[presence tracking, loop cycling, and event broadcasting]: ./2016-10-06-jamming-with-phoenix-presence.html
[race condition]: ./2016-10-08-phoenix-channel-race-conditions.html
[how we implemented presence]: ./2016-10-06-jamming-with-phoenix-presence.html
[ExUnit]: http://elixir-lang.org/docs/stable/ex_unit/ExUnit.html
[`Phoenix.ChannelTest`]: https://hexdocs.pm/phoenix/Phoenix.ChannelTest.html
[`UserSocketTest`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/user_socket_test.exs
[`JamChannelTest`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/jam_channel_test.exs
[next post]: ./2016-10-13-injecting-agent-names-in-elixir-tests.html
