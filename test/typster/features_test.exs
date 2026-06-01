defmodule Typster.FeaturesTest do
  use ExUnit.Case, async: false

  alias Typster.Accounts.Scope
  alias Typster.Features

  # A stand-in for the private Typster.Pro.Features, injected via the
  # :features_impl override so we can exercise dispatch without the submodule.
  defmodule FakePro do
    def can?(%Scope{plan: :pro}, _feature), do: true
    def can?(_scope, _feature), do: false
  end

  setup do
    on_exit(fn -> Application.delete_env(:typster, :features_impl) end)
    :ok
  end

  describe "catalog/0" do
    test "lists only paid Share features, never editor features" do
      catalog = Features.catalog()
      assert :share_write_scoped in catalog
      assert :share_embed_sandbox in catalog
      refute :compile in catalog
      refute :live_collaborators in catalog
    end
  end

  describe "can?/2 (open-core fallback)" do
    # Force the Free impl so these assert the community-build contract even when
    # the Pro submodule (Typster.Pro.Features) happens to be compiled in locally.
    setup do
      Application.put_env(:typster, :features_impl, Typster.Features.Free)
      :ok
    end

    test "denies every Pro feature when no Pro impl is loaded" do
      scope = %Scope{user: nil, plan: :free}

      for feature <- Features.catalog() do
        refute Features.can?(scope, feature), "expected #{feature} denied on free build"
      end
    end

    test "denies Pro features even for a nominally :pro scope without Pro code" do
      scope = %Scope{plan: :pro}
      refute Features.can?(scope, :share_embed_sandbox)
    end

    test "raises on an unknown feature (strict boundary)" do
      assert_raise FunctionClauseError, fn ->
        Features.can?(%Scope{}, :not_a_real_feature)
      end
    end
  end

  describe "can?/2 (dispatch to Pro)" do
    test "delegates to the injected Pro implementation" do
      Application.put_env(:typster, :features_impl, FakePro)
      assert Features.can?(%Scope{plan: :pro}, :share_advanced_link)
      refute Features.can?(%Scope{plan: :free}, :share_advanced_link)
    end
  end

  describe "plan/1 and pro?/1" do
    test "reads the scope's nominal plan, defaulting to free" do
      assert Features.plan(%Scope{plan: :pro}) == :pro
      assert Features.plan(%Scope{plan: :free}) == :free
      assert Features.plan(nil) == :free
    end

    test "pro?/1 reflects the nominal plan" do
      assert Features.pro?(%Scope{plan: :pro})
      refute Features.pro?(%Scope{plan: :free})
      refute Features.pro?(nil)
    end
  end
end
