# based on <Elixir in Action>'s example of a todo server (in todo_server.ex)

defmodule ServerProcess do
  def start(callback_module) do
    spawn(fn ->
      initial_state = callback_module.init
      loop(callback_module, initial_state)
    end)
  end

  defp loop(callback_module, current_state) do
    receive do
      {:call, request, caller} ->
        {response, new_state} =
          callback_module.handle_call(
            request,
            current_state
          )

        send(caller, {:response, response})
        loop(callback_module, new_state)

      {:cast, request} ->
        new_state =
          callback_module.handle_cast(
            request,
            current_state
          )

        loop(callback_module, new_state)
    end
  end

  def call(server_pid, request) do
    send(server_pid, {:call, request, self()})

    receive do
      {:response, response} ->
        response
    end
  end

  def cast(server_pid, request) do
    send(server_pid, {:cast, request})
  end
end

# sample entry:
# %{
#   question: "what is your favorite roadside attraction?",
#   answers:
#   [
#     %{type: "text", answer: "the world's largest ball of twine"},
#     %{type: "image", answer: "World's Largest Stucco Snowman", url:"https://www.roadsideamerica.com/attract/images-icon/mn/MNNSPsnowman_mw5546_320x480.jpg"}
#   ]
# }

defmodule IcebreakerServer do
  def start do
    ServerProcess.start(IcebreakerServer)
  end

  def put(pid, entry) do
    ServerProcess.cast(pid, {:add_entry, entry})
  end

  def getQuestion(pid, question) do
    ServerProcess.call(pid, {:entries, question})
  end

  def getAllQuestions(pid) do
    ServerProcess.call(pid, {:all_entries})
  end

  def init do
    IcebreakerList.new()
  end

  def handle_cast({:add_entry, entry}, state) do
    IcebreakerList.add_entry(state, entry)
  end

  def handle_call({:entries, question}, state) do
    {IcebreakerList.entries(state, question), state}
  end

  def handle_call({:all_entries}, state) do
    {IcebreakerList.entries(state), state}
  end
end

defmodule IcebreakerList do
  defstruct auto_id: 1, entries: %{}

  def new(entries \\ []) do
    Enum.reduce(
      entries,
      %IcebreakerList{},
      &add_entry(&2, &1)
    )
  end

  def add_entry(icebreaker_list, entry) do
    entry = Map.put(entry, :id, icebreaker_list.auto_id)
    new_entries = Map.put(icebreaker_list.entries, icebreaker_list.auto_id, entry)

    %IcebreakerList{icebreaker_list | entries: new_entries, auto_id: icebreaker_list.auto_id + 1}
  end

  def entries(icebreaker_list, question) do
    icebreaker_list.entries
    |> Stream.filter(fn {_, entry} -> entry.question == question end)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  def update_entry(icebreaker_list, %{} = new_entry) do
    update_entry(icebreaker_list, new_entry.id, fn _ -> new_entry end)
  end

  def update_entry(icebreaker_list, entry_id, updater_fun) do
    case Map.fetch(icebreaker_list.entries, entry_id) do
      :error ->
        icebreaker_list

      {:ok, old_entry} ->
        new_entry = updater_fun.(old_entry)
        new_entries = Map.put(icebreaker_list.entries, new_entry.id, new_entry)
        %IcebreakerList{icebreaker_list | entries: new_entries}
    end
  end

  def delete_entry(icebreaker_list, entry_id) do
    %IcebreakerList{icebreaker_list | entries: Map.delete(icebreaker_list.entries, entry_id)}
  end
end
