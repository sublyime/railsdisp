require "test_helper"

class DispersionCalculationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dispersion_calculations_index_url
    assert_response :success
  end

  test "should get show" do
    get dispersion_calculations_show_url
    assert_response :success
  end

  test "should get new" do
    get dispersion_calculations_new_url
    assert_response :success
  end

  test "should get create" do
    get dispersion_calculations_create_url
    assert_response :success
  end

  test "should get edit" do
    get dispersion_calculations_edit_url
    assert_response :success
  end

  test "should get update" do
    get dispersion_calculations_update_url
    assert_response :success
  end

  test "should get destroy" do
    get dispersion_calculations_destroy_url
    assert_response :success
  end
end
