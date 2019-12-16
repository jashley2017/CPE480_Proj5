# Cache Coherency 
1. Receives input:
    * Mem_address
    * Writing?
    * mem_address_in_other_cache
    * data @ address
    * in_transaction_core_1?
    * in_transaction_core_2?
    * in_transaction = in_tranasaction_core_2 | in_transaction_core_1
2. Checks other cache for mem_address
    * calls mem_address_from_other cache
    * If mem_address_in_other_cache
        - Pull dirty bit and data from cache
        - Do 3
    * else do 4
3. Case
  * If in_transaction? 
    - If writing 
      * SIGTMV
    - elsif reading & and addr in other cache dirty
      * SIGTMV
    - else
      * write/read data to your cache
  * else
    - If writing 
      * write to other cache and read from other cache
    - Elif !writing
      * read from other cache
4. Do the cache operation in your own cache










## Verilog Notes
Cache variables of note:
    * ccaddr - the addr the other cache is working on. This should be compared against the addrs in the cache and set the occstrobe (output ccstrobe) high if found.
    * ccstrobe - will be high if ccaddr is in other cache
    * if the ccstrobe comes back high, then we need to start looking into the cache coherency logic
