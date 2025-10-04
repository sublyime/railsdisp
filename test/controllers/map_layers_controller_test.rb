require "test_helper"

class MapLayersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get map_layers_index_url
    assert_response :success
  end

  test "should get show" do
    get map_layers_show_url
    assert_response :success
  end

  test "should get create" do
    get map_layers_create_url
    assert_response :success
  end

  test "should get update" do
    get map_layers_update_url
    assert_response :success
  end

  test "should get destroy" do
    get map_layers_destroy_url
    assert_response :success
  end
end
