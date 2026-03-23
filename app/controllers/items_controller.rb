class ItemsController < ApplicationController
  def index
    items = Item.order(created_at: :desc)
    render json: items
  end

  def show
    item = Item.find(params[:id])
    render json: item
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Item not found" }, status: :not_found
  end

  def create
    item = Item.new(item_params)
    if item.save
      render json: item, status: :created
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    item = Item.find(params[:id])
    item.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Item not found" }, status: :not_found
  end

  private

  def item_params
    params.require(:item).permit(:name, :description)
  end
end
