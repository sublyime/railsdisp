require "test_helper"

class TerrainPointsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get terrain_points_index_url
    assert_response :success
  end

  test "should get show" do
    get terrain_points_show_url
    assert_response :success
  end

  test "should get create" do
    get terrain_points_create_url
    assert_response :success
  end

  test "should get update" do
    get terrain_points_update_url
    assert_response :success
  end

  test "should get destroy" do
    get terrain_points_destroy_url
    assert_response :success
  end

  test "should get interpolate" do
    get terrain_points_interpolate_url
    assert_response :success
  end
end
