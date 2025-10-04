class DispersionEvent < ApplicationRecord
  belongs_to :chemical
  belongs_to :location
  has_many :receptors, dependent: :destroy
  has_many :dispersion_calculations, dependent: :destroy
  
  validates :release_type, presence: true, inclusion: { 
    in: %w[instantaneous continuous puff jet fire explosion] 
  }
  validates :started_at, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[planned active completed cancelled] 
  }
  
  # At least one release parameter must be specified
  validate :at_least_one_release_parameter
  
  scope :active, -> { where(status: 'active') }
  scope :recent, -> { where('started_at >= ?', 7.days.ago) }
  scope :by_chemical, ->(chemical_id) { where(chemical_id: chemical_id) }
  
  before_create :set_default_status
  after_update :update_calculations, if: :saved_change_to_release_parameters?
  
  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end
  
  def active?
    status == 'active'
  end
  
  def total_release_mass
    if release_mass.present?
      release_mass
    elsif release_volume.present? && chemical.density.present?
      release_volume * chemical.density
    elsif release_rate.present? && release_duration.present?
      release_rate * release_duration
    else
      nil
    end
  end
  
  def source_strength
    # Calculate source strength in g/s for dispersion modeling
    return 0 unless active?
    
    case release_type
    when 'instantaneous', 'puff'
      total_release_mass.to_f / 1.0  # Assume 1 second for instantaneous
    when 'continuous'
      release_rate.to_f
    else
      release_rate.to_f || (total_release_mass.to_f / release_duration.to_f)
    end
  end
  
  private
  
  def at_least_one_release_parameter
    unless release_rate.present? || release_volume.present? || release_mass.present?
      errors.add(:base, 'At least one release parameter (rate, volume, or mass) must be specified')
    end
  end
  
  def set_default_status
    self.status ||= 'planned'
  end
  
  def saved_change_to_release_parameters?
    saved_change_to_release_rate? || 
    saved_change_to_release_volume? || 
    saved_change_to_release_mass? ||
    saved_change_to_release_duration?
  end
  
  def update_calculations
    # Trigger recalculation of dispersion models
    DispersionCalculationJob.perform_later(self) if active?
  end
end
