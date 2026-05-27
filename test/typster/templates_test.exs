defmodule Typster.TemplatesTest do
  use Typster.DataCase, async: true

  alias Typster.Templates

  setup do
    user = Typster.AccountsFixtures.user_fixture()
    %{scope: Typster.Accounts.Scope.for_user(user)}
  end

  test "create, list and delete templates scoped to the user", %{scope: scope} do
    assert Templates.list_templates(scope) == []

    {:ok, tpl} = Templates.create_template(scope, %{name: "ieee.typ", content: "= Paper"})
    assert [listed] = Templates.list_templates(scope)
    assert listed.id == tpl.id
    assert listed.content == "= Paper"

    other = Typster.Accounts.Scope.for_user(Typster.AccountsFixtures.user_fixture())
    assert Templates.list_templates(other) == []

    assert {:ok, _} = Templates.delete_template(scope, tpl)
    assert Templates.list_templates(scope) == []
  end

  test "requires a name", %{scope: scope} do
    assert {:error, changeset} = Templates.create_template(scope, %{content: "x"})
    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end
end
