import logging
from tmu.models.classification.coalesced_classifier import TMCoalescedClassifier
import SOURCES.config as config

_LOGGER = logging.getLogger(__name__)

def create_tm():
    _LOGGER.info("Creating Coalesced Tsetlin Machine instance from local configuration guidelines...")
    
    tm = TMCoalescedClassifier(
        number_of_clauses=config.NUM_CLAUSES,
        T=config.T,
        s=config.S,
        weighted_clauses=config.WEIGHTED_CLAUSES,
        focused_negative_sampling=config.FOCUSED_NEGATIVE_SAMPLING,
        platform=config.PLATFORM
    )
    return tm