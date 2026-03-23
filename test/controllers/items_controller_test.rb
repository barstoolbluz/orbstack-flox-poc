require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @item = Item.create!(name: "Test Item", description: "A test item")
  end

  test "health check returns ok when database is connected" do
    get "/health"
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal "connected", json["database"]
  end

  test "index returns items" do
    get "/items"
    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert json.any? { |i| i["name"] == "Test Item" }
  end

  test "create item with valid params" do
    assert_difference("Item.count", 1) do
      post "/items", params: { item: { name: "New Item", description: "Desc" } }, as: :json
    end
    assert_response :created
  end

  test "create item with invalid params returns error" do
    post "/items", params: { item: { name: "" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "show item" do
    get "/items/#{@item.id}"
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Test Item", json["name"]
  end

  test "destroy item" do
    assert_difference("Item.count", -1) do
      delete "/items/#{@item.id}"
    end
    assert_response :no_content
  end
end
