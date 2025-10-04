class Chemical < ApplicationRecord
  has_many :dispersion_events, dependent: :destroy
  
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :cas_number, presence: true, uniqueness: { case_sensitive: false }
  validates :molecular_weight, presence: true, numericality: { greater_than: 0 }
  validates :state, presence: true, inclusion: { in: %w[gas liquid solid] }
  validates :hazard_class, presence: true
  
  scope :by_state, ->(state) { where(state: state) }
  scope :by_hazard_class, ->(hazard_class) { where(hazard_class: hazard_class) }
  
  def display_name
    "#{name} (#{cas_number})"
  end
  
  # Calculate dispersion coefficients based on chemical properties
  def dispersion_coefficient
    # Simplified calculation - in reality this would be much more complex
    case state
    when 'gas'
      vapor_pressure.to_f / molecular_weight.to_f
    when 'liquid'
      density.to_f * vapor_pressure.to_f
    else
      0.1 # Default for solids
    end
  end
end
