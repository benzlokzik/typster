defmodule TypsterWeb.FileTree do
  @moduledoc """
  Builds and renders the editor sidebar's file/asset navigation in three view
  modes — `:tree` (foldable folders), `:smart` (single-file folders inlined as
  `dir/file.ext`), and `:flat` (full paths) — from a flat list of `%File{}` /
  `%Asset{}` records keyed by their `path`/`filename`.
  """
  use TypsterWeb, :html

  @doc "Short label for the current view mode (for the switcher button)."
  def view_label(:smart), do: gettext("editor.view.smart")
  def view_label(:flat), do: gettext("editor.view.flat")
  def view_label(_tree), do: gettext("editor.view.tree")

  @doc "Normalize the mode string from the client into a known atom (no String.to_atom on input)."
  def mode("smart"), do: :smart
  def mode("flat"), do: :flat
  def mode(_), do: :tree

  @doc "Build render nodes for the file list in the given mode."
  def file_nodes(files, mode) do
    files
    |> Enum.map(fn f ->
      %{path: f.path, id: f.id, editable: Typster.Files.editable_file?(f), asset?: false}
    end)
    |> by_mode(mode)
  end

  @doc "Build render nodes for the assets list in the given mode."
  def asset_nodes(assets, mode) do
    assets
    |> Enum.map(fn a ->
      %{path: a.filename, id: a.id, asset?: true, editable: false, meta: human_size(a.size)}
    end)
    |> by_mode(mode)
  end

  defp by_mode(items, :flat), do: Enum.map(items, &Map.merge(&1, %{type: :leaf, name: &1.path}))
  defp by_mode(items, :smart), do: items |> build_tree() |> smart_collapse()
  defp by_mode(items, _tree), do: build_tree(items)

  @doc false
  def build_tree(items) do
    Enum.reduce(items, [], fn item, nodes ->
      insert(nodes, String.split(item.path, "/"), item, "")
    end)
  end

  defp insert(nodes, [name], item, _prefix) do
    nodes ++ [Map.merge(item, %{type: :leaf, name: name})]
  end

  defp insert(nodes, [name | rest], item, prefix) do
    dir_path = if prefix == "", do: name, else: prefix <> "/" <> name

    case Enum.find_index(nodes, &(&1.type == :dir and &1.name == name)) do
      nil ->
        dir = %{
          type: :dir,
          name: name,
          path: dir_path,
          children: insert([], rest, item, dir_path)
        }

        nodes ++ [dir]

      idx ->
        dir = Enum.at(nodes, idx)
        List.replace_at(nodes, idx, %{dir | children: insert(dir.children, rest, item, dir_path)})
    end
  end

  # Collapse directories that hold exactly one (non-dir) child into "dir/child".
  defp smart_collapse(nodes) do
    Enum.map(nodes, fn
      %{type: :dir, children: [%{type: :leaf} = child]} = dir ->
        Map.merge(child, %{name: dir.name <> "/" <> child.name, smart: true})

      %{type: :dir, children: children} = dir ->
        %{dir | children: smart_collapse(children)}

      leaf ->
        leaf
    end)
  end

  @doc "Human-readable byte size in SI units, e.g. `248 kB`."
  def human_size(nil), do: ""
  def human_size(b) when b < 1000, do: "#{b} B"
  def human_size(b) when b < 1_000_000, do: "#{round(b / 1000)} kB"
  def human_size(b), do: "#{Float.round(b / 1_000_000, 1)} MB"

  defp expanded?(collapsed, path), do: not MapSet.member?(collapsed, path)

  defp leaf_dom_id(%{asset?: true, id: id}), do: "asset-entry-#{id}"
  defp leaf_dom_id(%{id: id}), do: "select-file-#{id}"

  attr :nodes, :list, required: true
  attr :depth, :integer, default: 0
  attr :collapsed, :any, required: true
  attr :current_id, :any, default: nil

  @doc "Recursively render tree rows (siblings share one `<ul>`, indented by depth)."
  def tree_rows(assigns) do
    ~H"""
    <%= for node <- @nodes do %>
      <%= if node.type == :dir do %>
        <li
          class="ts-tree__item ts-tree__dir"
          style={"padding-left: #{6 + @depth * 14}px"}
          phx-click="toggle_dir"
          phx-value-path={node.path}
        >
          <.icon
            name={
              if expanded?(@collapsed, node.path), do: "hero-chevron-down", else: "hero-chevron-right"
            }
            class="size-3"
          />
          <.icon
            name={if expanded?(@collapsed, node.path), do: "hero-folder-open", else: "hero-folder"}
            class="size-3.5"
          />
          <span class="truncate flex-1">{node.name}</span>
          <span class="ts-tree__count">{length(node.children)}</span>
        </li>
        <.tree_rows
          :if={expanded?(@collapsed, node.path)}
          nodes={node.children}
          depth={@depth + 1}
          collapsed={@collapsed}
          current_id={@current_id}
        />
      <% else %>
        <li
          id={leaf_dom_id(node)}
          phx-click={if not node.asset? and node.editable, do: "select_file"}
          phx-value-file-id={node.id}
          class={[
            "ts-tree__item",
            (node.asset? or not node.editable) && "is-disabled",
            (not node.asset? and @current_id == node.id) && "is-active"
          ]}
          style={"padding-left: #{6 + @depth * 14 + 14}px"}
        >
          <.icon name={if node.asset?, do: "hero-photo", else: "hero-document-text"} class="size-3.5" />
          <span class="truncate flex-1">{node.name}</span>
          <span :if={Map.get(node, :smart)} class="ts-tree__smart">↳</span>
          <span :if={Map.get(node, :meta, "") != ""} class="ts-tree__pill">{node.meta}</span>
        </li>
      <% end %>
    <% end %>
    """
  end
end
