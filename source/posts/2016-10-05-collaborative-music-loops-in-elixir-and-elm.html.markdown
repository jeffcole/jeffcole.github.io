---
title: "Collaborative Music Loops in Elixir and Elm"
date: 2016-10-05 13:21 UTC
---


When I started learning [Elixir] and checking out [Phoenix], one of the things that struck me was the platform's first-class support for the real-time web. Once you get a handle on Elixir and become accustomed to programming in a functional style, it's a joy to work with the abstractions that the Phoenix team has set up around sockets and channels.

I came up with an idea for a project to test drive these features. And if I was going to be using functional programming, I figured I might as well do it all the way up the stack. The [Elm] language stands to transform how we write client-side applications, along with how well we enjoy the experience.

In this series, I want to highlight the interesting abstractions provided by Elixir, Phoenix, and Elm that make building these types of applications much more pleasant than in the past.

The first few posts in the series will explore how Elixir and Phoenix gave me the right tools to write the back end for [Loops With Friends], a collaborative music-making web app. The app supports up to seven users in a given "jam," in which each user gets their own music loop. Each user can start and stop their loop to make music in real time with the other users in the jam. The app automatically creates and balances additional jams as necessary as users join and leave.

As we go, I'll highlight the bits of code that are relevant to understanding how everything is wired together, incrementally adding lines to existing functions. Be sure to check out the full code via the links if you'd like to see the final source and tests. We won't spend much time on the details of data transformation, so if you're new to Elixir, a great place to start is the [Elixir Guides].

## Joining a Jam

When a player visits the app, the server sends down the client-side code, along with a jam identifier. The client-side code then immediately requests a WebSocket connection to a Phoenix channel for that identifier. The server application's `Endpoint` module [[source][Endpoint source]] binds the `/socket` path to the `UserSocket` module.

~~~ elixir
# lib/loops_with_friends/endpoint.ex
defmodule LoopsWithFriends.Endpoint do
  use Phoenix.Endpoint, otp_app: :loops_with_friends

  socket "/socket", LoopsWithFriends.UserSocket

  # ...
end
~~~

The `UserSocket` module [[source][UserSocket source] \| [test][UserSocket test]] declares the channels that are supported over the socket. The pattern `"jams:*"` specifies what topics requested by the client the channel will match on. Meanwhile, the `connect` function assigns a user ID to the socket so that we can know which user we are communicating with at all points after the initial connection.


~~~ elixir
# web/channels/user_socket.ex
defmodule LoopsWithFriends.UserSocket do
  use Phoenix.Socket

  channel "jams:*", LoopsWithFriends.JamChannel

  def connect(_params, socket) do
    {:ok, assign(socket, :user_id, UUID.uuid4())}
  end
end
~~~

Finally, the `JamChannel` module [[source][JamChannel source] \| [test][JamChannel test]] implements the `join` function, which matches on the topic requested by the client, replies with the user's ID, and assigns the jam ID to the socket.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  use LoopsWithFriends.Web, :channel

  def join("jams:" <> jam_id, _params, socket) do
    # ...

    {:ok,
     %{user_id: socket.assigns.user_id},
     assign(socket, :jam_id, jam_id)}
  end
end
~~~

At this point, the user has successfully joined the jam — but a jam of one is a very lonely jam.

Continue to the [next post] to see how Phoenix Presence allows us to easily track all the players in a jam.


[Elixir]: http://elixir-lang.org/
[Phoenix]: http://www.phoenixframework.org/
[Elm]: http://elm-lang.org/
[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[Elixir Guides]: http://elixir-lang.org/getting-started/introduction.html
[Endpoint source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/endpoint.ex
[UserSocket source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/user_socket.ex
[UserSocket test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/user_socket_test.exs
[JamChannel source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/jam_channel.ex
[JamChannel test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/jam_channel_test.exs
[next post]: ./2016-10-06-jamming-with-phoenix-presence.html
