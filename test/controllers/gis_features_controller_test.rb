require "test_helper"

class GisFeaturesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get gis_features_index_url
    assert_response :success
  end

  test "should get show" do
    get gis_features_show_url
    assert_response :success
  end

  test "should get create" do
    get gis_features_create_url
    assert_response :success
  end

  test "should get update" do
    get gis_features_update_url
    assert_response :success
  end

  test "should get destroy" do
    get gis_features_destroy_url
    assert_response :success
  end
end
