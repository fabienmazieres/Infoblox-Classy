#Variables
$Global:WapiVersion = 'v2.2'
#Helper Functions
Function ConvertTo-PTRName {
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [ipaddress]$IPAddress
    )
    BEGIN{}    
    PROCESS{
        $Octets = $IPAddress.IPAddressToString.split('.')
        $name = "$($octets[3]).$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
        return $name
    }
    END{}
}
Function ConvertFrom-PTRName {
	Param(
		[Parameter(mandatory=$True,ValueFromPipeline=$True)]
		[String]$PTRName
	)
	BEGIN{}
	PROCESS{
		$Octets = $PTRName.split('.')
		[IPAddress]$IPAddress = "$($octets[3]).$($octets[2]).$($octets[1]).$($octets[0])"
		return $IPAddress
	}
	END{}
}
Function ConvertTo-ExtAttrsArray {
    Param (
        [Parameter(ValueFromPipeline=$True)]
        [Object]$extattrs
    )
    BEGIN{}
    PROCESS{
        If ($Extattrs) {
            $ExtAttrList = $Extattrs | get-member | where-object{$_.MemberType -eq 'NoteProperty'}
            Foreach ($ExtAttr in $ExtAttrList){
                $objExtAttr = New-object PSObject -Property @{
                    Name = $Extattr.Name
                }
                Foreach ($property in $($ExtAttrs.$($Extattr.Name) | get-member | where-object{$_.membertype -eq 'noteproperty'})) {
                    $objExtAttr | Add-Member -MemberType NoteProperty -name $property.Name -Value $($Extattrs.$($extattr.name).$($property.name))
                }
                $objextattr
            }
        } else {
            return $Null
        }
    }
    END{}
}
Function ConvertFrom-ExtAttrsArray {
	Param (
		[Parameter(ValueFromPipeline=$True)]
		[object]$ExtAttrib
	)
	BEGIN{}
	PROCESS{
		$objextattr = New-Object psobject -Property @{}
		Foreach ($extattr in $extattrib){
			$Value = new-object psobject -Property @{value=$ExtAttrib.value}
			$objextattr | Add-Member -MemberType NoteProperty -Name $($ExtAttrib.Name) -Value $Value
		}
		$objextattr
	}
	END{}
}
Function SearchstringToIBQuery {
    param ($SearchString)
    $Words = $Searchstring.split(' ')
    $property = $words[0]
    $Operator = $words[1]
    $Value = $words[2..$($words.length -1)] -join ' ' -replace "`"" -replace "`'"
    If ($operator -eq '-eq'){$iboperator = ':='}
    If ($operator -eq '-like'){$iboperator = '~:='}
    $IBQueryString = "*$property$iboperator$value&"
    return $IBQueryString
}
Class IB_ReferenceObject {
    #properties
    hidden [String]$gridmaster
    hidden [System.Management.Automation.PSCredential]
		   [System.Management.Automation.Credential()]
		   $Credential

    [String]$_ref
    #methods
	
    [String] ToString(){
        return $this._ref
    }
	static [IB_ReferenceObject] Get(
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[string]$_ref
	) {
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
        If ($Return) {
			return [IB_ReferenceObject]::New($Gridmaster,$Credential,$return._ref)
		} else {
			return $null
		}
	}
   hidden [String] Delete(){
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $return = Invoke-RestMethod -Uri $URIString -Method Delete -Credential $this.Credential
        return $return
    }
    #constructors
    IB_ReferenceObject(){}
    IB_ReferenceObject(
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	){
		$this.gridmaster = $Gridmaster
		$this.credential = $Credential
		$this._ref = $_ref
	}
}
Class IB_DNSARecord : IB_ReferenceObject {
    ##Properties
    [String]$Name
    [IPAddress]$IPAddress
    [String]$Comment
    [String]$View
    [uint32]$TTL
    [bool]$Use_TTL
	[Object]$ExtAttrib

#region Methods
    #region Create method
    static [IB_DNSARecord] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
        [IPAddress]$IPAddress,
        [String]$Comment,
        [String]$view,
        [uint32]$TTL,
        [bool]$Use_TTL
    ){
        $URIString = "https://$GridMaster/wapi/$Global:WapiVersion/record:a"
        $BodyHashTable = @{name=$Name}
        $bodyhashtable += @{ipv4addr=$IPAddress}
        $bodyhashtable += @{comment=$comment}
        If ($view){$bodyhashtable += @{view = $view}}

        If ($Use_TTL){
            $BodyHashTable+= @{ttl = $TTL}
            $BodyHashTable+= @{use_ttl = $use_ttl}
        }

        $return = Invoke-RestMethod -Uri $URIString -Method Post -Body $BodyHashTable -Credential $Credential
		If ($return) {
			return [IB_DNSARecord]::Get($GridMaster,$Credential,$return)
		}else {
			return $Null
		}
        
    }
    #endregion
    #region Get methods
		static [IB_DNSARecord] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "extattrs,name,ipv4addr,comment,view,ttl,use_ttl"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
        If ($Return) {
			If ($return.ipv4addr.length -eq 0){$return.ipv4addr = $Null}
			return [IB_DNSARecord]::New($return.name,
										$return.ipv4addr,
										$return.comment,
										$return._ref,
										$return.view,
										$Gridmaster,
										$Credential,
										$return.TTL,
										$return.use_TTL,
										$($Return.extattrs | ConvertTo-ExtAttrsArray))
		} else {
			return $null
		}
	}

    static [IB_DNSARecord[]] Get(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[IPAddress]$IPAddress,
		[String]$Comment,
		[String]$ExtAttribFilter,
		[String]$Zone,
        [String]$View,
        [Bool]$Strict,
        [Int]$MaxResults
    ){
		$ReturnFields = "extattrs,name,ipv4addr,comment,view,ttl,use_ttl"
		$URI = "https://$Gridmaster/wapi/$Global:WapiVersion/record:a?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($Name){
			$URI += "name$Operator$Name&"
		}
		If ($IPAddress){
			$URI += "ipv4addr=$($ipaddress.IPAddressToString)&"
		}
		If ($comment){
			$URI += "comment$operator$comment&"
		}
		If ($ExtAttribFilter){
			$URI += SearchStringToIBQuery -searchstring $ExtAttribFilter
		}
		If ($Zone){
			$URI += "zone=$Zone&"
		}
		If ($View){
			$URI += "view=$view&"
		}
        If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
		Foreach ($item in $return){
			If ($item.ipv4addr.length -eq 0){$item.ipv4addr = $Null}
			$output += [IB_DNSARecord]::New($item.name,
											$item.ipv4addr,
											$item.comment,
											$item._ref,
											$item.view,
											$Gridmaster,
											$Credential,
											$item.TTL,
											$item.use_TTL,
											$($item.extattrs | convertTo-ExtAttrsArray))
		}
        return $output
    }
    #endregion
    #region Set method
    hidden [void]Set(
        [IPAddress]$IPAddress,
        [String]$Comment,
        [uint32]$ttl,
        [bool]$use_ttl
    ){
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyHashTable = $null
        $bodyHashTable+=@{ipv4addr=$($IPAddress.IPAddressToString)}
        $bodyHashTable+=@{comment=$comment}
        $bodyHashTable+=@{use_ttl=$use_ttl}
        If ($use_ttl){
            $bodyHashTable+=@{ttl=$ttl}
        } else {
			$bodyHashTable += @{ttl=0}
		}
        If ($bodyHashTable){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $($bodyHashTable | ConvertTo-Json) -ContentType application/json -Credential $this.Credential
			if ($return) {
				$this._ref = $return
				$this.ipaddress = $IPAddress
				$this.comment = $Comment
				$this.use_ttl = $use_ttl
				If ($use_ttl){
					$this.ttl = $ttl
				} else {
					$this.ttl = $null
				}
			}
		}
    }
    #endregion
	#region AddExtAttrib method
	hidden [void] AddExtAttrib (
		[String]$Name,
		[String]$Value
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $Name -Value $(New-object psobject -Property @{value=$Value})
		$ExtAttr = new-object psobject -Property @{$Name=$(get-variable $Name | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs+"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_DNSARecord]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
	#region RemoveExtAttrib method
	hidden [void] RemoveExtAttrib (
		[String]$ExtAttrib
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $ExtAttrib -Value $(New-object psobject -Property @{})
		$ExtAttr = new-object psobject -Property @{$extattrib=$(get-variable $ExtAttrib | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs-"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_DNSARecord]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
#endregion
#region Constructors
    IB_DNSARecord(
        [String]$Name,
        [IPAddress]$IPAddress,
        [String]$Comment,
        [String]$_ref,
        [String]$view,
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [uint32]$ttl,
        [bool]$use_ttl,
		[Object]$ExtAttrib
    ){
        $this.Name        = $Name
        $this.IPAddress   = $IPAddress
        $this.Comment     = $Comment
        $this._ref        = $_ref
        $this.view        = $view
        $this.gridmaster  = $Gridmaster
        $this.credential  = $Credential
        $this.TTL         = $ttl
        $this.use_ttl     = $use_ttl
		$this.extattrib   = $ExtAttrib
    }
#endregion
}
Class IB_DNSCNameRecord : IB_ReferenceObject {
    ##Properties
    [String]$Name
    [String]$canonical
    [String]$Comment
    [String]$view
    [uint32]$TTL
    [bool]$Use_TTL
	[Object]$ExtAttrib

#region Methods
    #region Create method
    static [IB_DNSCNameRecord] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
        [String]$canonical,
        [String]$Comment,
        [String]$view,
        [uint32]$TTL,
        [bool]$Use_TTL

    ){
        
        $URIString = "https://$GridMaster/wapi/$Global:WapiVersion/record:cname"
        $BodyHashTable = @{name=$Name}
        $bodyhashtable += @{canonical=$Canonical}
        $bodyhashtable += @{comment=$comment}
        If ($View){$bodyhashtable += @{view = $view}}
        If ($use_ttl){
            $BodyHashTable += @{ttl = $ttl}
            $BodyHashTable += @{use_ttl = $use_ttl}
        }
        $return = Invoke-RestMethod -Uri $URIString -Method Post -Body $BodyHashTable -Credential $Credential
        If ($Return) {
			return [IB_DNSCNameRecord]::Get($GridMaster,$Credential,$return)
		} else {
			return $Null
		}
    }
    #endregion
    #region Get methods
	static [IB_DNSCNameRecord] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "extattrs,name,canonical,comment,view,ttl,use_ttl"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
        If ($return) {
			return [IB_DNSCNameRecord]::New($return.Name,
											$return.canonical,
											$return.comment,
											$return._ref,
											$return.view,
											$gridmaster,
											$credential,
											$return.ttl,
											$return.use_ttl,
											$($Return.extattrs | ConvertTo-ExtAttrsArray))
		} else {
			return $Null
		}
	}


    static [IB_DNSCNameRecord[]] Get(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[String]$Canonical,
		[String]$Comment,
		[String]$ExtAttribFilter,
		[String]$Zone,
        [String]$View,
        [Bool]$Strict,
        [Int]$MaxResults
    ){
		$ReturnFields = "extattrs,name,canonical,comment,view,ttl,use_ttl"
		$URI = "https://$Gridmaster/wapi/$Global:WapiVersion/record:cname?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($Name){
			$URI += "name$Operator$Name&"
		}
		If ($Canonical){
			$URI += "canonical$operator$Canonical&"
		}
		If ($comment){
			$URI += "comment$operator$comment&"
		}
		If ($ExtAttribFilter){
			$URI += SearchStringToIBQuery -searchstring $ExtAttribFilter
		}
		If ($Zone){
			$URI += "zone=$Zone&"
		}
		If ($View){
			$URI += "view=$view&"
		}
        If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
        Foreach ($item in $return){
                $output += [IB_DNSCNameRecord]::New($item.Name,
													$item.canonical,
													$item.comment,
													$item._ref,
													$item.view,
													$gridmaster,
													$credential,
													$item.ttl,
													$item.use_ttl,
													$($item.extattrs | ConvertTo-ExtAttrsArray))
        }
        return $output
    }
    #endregion
    #region Set method
    hidden [Void] Set(
        [String]$canonical,
        [String]$Comment,
        [uint32]$TTL,
        [bool]$Use_TTL

    ){
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyHashTable = $null
        $bodyHashTable+=@{canonical=$canonical}
        $bodyHashTable+=@{comment=$comment}
        $bodyHashTable+=@{use_ttl=$use_ttl}
        If ($use_ttl){
            $bodyHashTable+=@{ttl=$ttl}
        } else {
			$bodyHashTable += @{ttl=0}
		}

        If ($bodyHashTable){
			$return = Invoke-RestMethod -Uri $URIString -Method Put -Body $($bodyHashTable | ConvertTo-Json) -ContentType application/json -Credential $this.Credential
			if ($return) {
				$this._ref = $return
				$this.canonical = $canonical
				$this.comment = $Comment
				$this.use_ttl = $use_ttl
				If ($use_ttl){
					$this.ttl = $ttl
				} else {
					$this.ttl = $null
				}
			}		
		}
    }
    #endregion
	#region AddExtAttrib method
	hidden [void] AddExtAttrib (
		[String]$Name,
		[String]$Value
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $Name -Value $(New-object psobject -Property @{value=$Value})
		$ExtAttr = new-object psobject -Property @{$Name=$(get-variable $Name | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs+"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_DNSCNameRecord]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
	#region RemoveExtAttrib method
	hidden [void] RemoveExtAttrib (
		[String]$ExtAttrib
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $ExtAttrib -Value $(New-object psobject -Property @{})
		$ExtAttr = new-object psobject -Property @{$extattrib=$(get-variable $ExtAttrib | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs-"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_DNSCNameRecord]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
#endregion

#region Constructors
    IB_DNSCNameRecord(
        [String]$Name,
        [String]$canonical,
        [String]$Comment,
        [String]$_ref,
        [String]$view,
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [uint32]$TTL,
        [bool]$Use_TTL,
		[Object]$ExtAttrib
    ){
        $this.Name        = $Name
        $this.canonical   = $canonical
        $this.Comment     = $Comment
        $this._ref        = $_ref
        $this.view        = $view
        $this.gridmaster  = $Gridmaster
        $this.credential  = $Credential
        $this.TTL         = $TTL
        $this.Use_TTL     = $use_ttl
		$this.extattrib   = $ExtAttrib
    }

#endregion
}
Class IB_DNSPTRRecord : IB_ReferenceObject {
    ##Properties
    [IPAddress]$IPAddress
    [String]$PTRDName
    [String]$Name
    [String]$Comment
    [String]$view
    [uint32]$TTL
    [bool]$Use_TTL
	[Object]$ExtAttrib

#region Methods
    #region Create method
    static [IB_DNSPTRRecord] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$PTRDName,
        [IPAddress]$IPAddress,
        [String]$Comment,
        [String]$view,
        [uint32]$TTL,
        [bool]$Use_TTL

    ){
        $URIString = "https://$GridMaster/wapi/$Global:WapiVersion/record:ptr"
        $BodyHashTable = @{ipv4addr=$($IPAddress.IPAddressToString)}
        $bodyhashtable += @{ptrdname=$PTRDName}
        $bodyhashtable += @{comment=$comment}
        If ($View){$bodyhashtable += @{view = $view}}
        If ($use_TTL){
            $BodyHashTable+= @{ttl=$ttl}
            $bodyhashtable+= @{use_ttl=$use_ttl}
        }
        $return = Invoke-RestMethod -Uri $URIString -Method Post -Body $BodyHashTable -Credential $Credential
        If ($Return) {
			return [IB_DNSPTRRecord]::Get($GridMaster,$Credential,$return)
		} else {
			return $Null
		}
    }
    #endregion
    #region Get methods
	static [IB_DNSPTRRecord] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "extattrs,name,ptrdname,ipv4addr,comment,view,ttl,use_ttl"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
        If ($Return) {
			If ($return.ipv4addr.length -eq 0){$return.ipv4addr = $Null}
			return [IB_DNSPTRRecord]::New($return.ptrdname,
										  $return.ipv4addr,
										  $return.Name,
										  $return.comment,
										  $return._ref,
										  $return.view,
										  $Gridmaster,
										  $credential,
										  $return.ttl,
										  $return.use_ttl,
										  $($return.extattrs | ConvertTo-ExtAttrsArray))
		} else {
			return $Null
		}
	}

    static [IB_DNSPTRRecord[]] Get(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[IPAddress]$IPAddress,
		[String]$PTRdname,
		[String]$Comment,
		[String]$ExtAttribFilter,
		[String]$Zone,
        [String]$View,
        [Bool]$Strict,
        [Int]$MaxResults
    ){
		$ReturnFields = "extattrs,name,ptrdname,ipv4addr,comment,view,ttl,use_ttl"
		$URI = "https://$Gridmaster/wapi/$Global:WapiVersion/record:ptr?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($Name){
			$URI += "name$Operator$Name&"
		}
		If ($IPAddress){
			$URI += "ipv4addr=$($ipaddress.IPAddressToString)&"
		}
		If ($PTRdname){
			$URI += "ptrdname$operator$PTRdname&"
		}
		If ($comment){
			$URI += "comment$operator$comment&"
		}
		If ($ExtAttribFilter){
			$URI += SearchStringToIBQuery -searchstring $ExtAttribFilter
		}
		If ($Zone){
			$URI += "zone=$Zone&"
		}
		If ($View){
			$URI += "view=$view&"
		}
        If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
        Foreach ($item in $return){
				If ($item.ipv4addr.length -eq 0){$item.ipv4addr = $Null}
                $output += [IB_DNSPTRRecord]::New($item.ptrdname,
												  $item.ipv4addr,
												  $item.name,
												  $item.comment,
												  $item._ref,
												  $item.view,
												  $Gridmaster,
												  $credential,
												  $item.ttl,
												  $item.use_ttl,
												  $($item.extattrs | ConvertTo-ExtAttrsArray))
        }
        return $output
    }
    #endregion
    #region Set method
    hidden [Void] Set(
        [String]$PTRDName,
        [String]$Comment,
        [uint32]$ttl,
        [bool]$use_ttl
    ){
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyHashTable = $null
        $bodyHashTable+=@{ptrdname=$PTRDName}
        $bodyHashTable+=@{comment=$comment}
        $bodyHashTable+=@{use_ttl=$use_ttl}
        If ($use_ttl){
            $bodyHashTable+=@{ttl=$ttl}
        } else {
			$bodyHashTable += @{ttl=0}
		}

        If ($bodyHashTable){
			$return = Invoke-RestMethod -Uri $URIString -Method Put -Body $($bodyHashTable | ConvertTo-Json) -ContentType application/json -Credential $this.Credential
			if ($return) {
				$this._ref = $return
				$this.ptrdname = $PTRDName
				$this.comment = $Comment
				$this.use_ttl = $use_ttl
				If ($use_ttl){
					$this.ttl = $ttl
				} else {
					$this.ttl = $null
				}

			}
		}
    }
    #endregion
	#region AddExtAttrib method
	hidden [void] AddExtAttrib (
		[String]$Name,
		[String]$Value
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $Name -Value $(New-object psobject -Property @{value=$Value})
		$ExtAttr = new-object psobject -Property @{$Name=$(get-variable $Name | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs+"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_DNSPTRRecord]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
	#region RemoveExtAttrib method
	hidden [void] RemoveExtAttrib (
		[String]$ExtAttrib
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $ExtAttrib -Value $(New-object psobject -Property @{})
		$ExtAttr = new-object psobject -Property @{$extattrib=$(get-variable $ExtAttrib | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs-"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_DNSPTRRecord]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
#endregion
#region Constructors
    IB_DNSPTRRecord(
        [String]$PTRDName,
        [IPAddress]$IPAddress,
        [String]$Name,
        [String]$Comment,
        [String]$_ref,
        [String]$view,
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [uint32]$TTL,
        [bool]$Use_ttl,
		[Object]$ExtAttrib
    ){
        $this.PTRDName    = $PTRDName
        $this.ipaddress   = $IPAddress
        $this.Name        = $Name
        $this.Comment     = $Comment
        $this._ref        = $_ref
        $this.view        = $view
        $this.gridmaster  = $Gridmaster
        $this.credential  = $Credential
        $this.ttl         = $TTL
        $this.Use_TTL     = $Use_ttl
		$this.extattrib   = $ExtAttrib
    }
#endregion
}

Class IB_ExtAttrsDef : IB_ReferenceObject {
    ##Properties
    [String]$Name
    [String]$Type
    [String]$Comment
    [String]$DefaultValue
#region Methods
    [String] ToString () {
        return $this.name
    }

    #region Create method
    static [IB_ExtAttrsDef] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[String]$Type,
		[String]$Comment,
		[String]$DefaultValue
    ){
        $URIString = "https://$GridMaster/wapi/$Global:WapiVersion/extensibleattributedef"
        $BodyHashTable = @{name=$Name}
        $bodyhashtable += @{type=$Type.ToUpper()}
        $bodyhashtable += @{comment=$comment}
		if ($defaultvalue){$bodyhashtable += @{default_value=$DefaultValue}}
        $return = Invoke-RestMethod -Uri $URIString -Method Post -Body $BodyHashTable -Credential $Credential
		If ($return) {
			return [IB_ExtAttrsDef]::Get($GridMaster,$Credential,$return)
		}else {
			return $Null
		}
        
    }
    #endregion
    #region Get methods
		static [IB_ExtAttrsDef] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "name,comment,default_value,type"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
        If ($Return) {
			return [IB_ExtAttrsDef]::New($gridmaster,$credential,$return.name,$return.type,$return.comment,$return.default_value,$return._ref)
		} else {
			return $null
		}
	}

    static [IB_ExtAttrsDef[]] Get(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[String]$Type,
		[String]$Comment,
        [Bool]$Strict,
        [Int]$MaxResults
    ){
		$ReturnFields = "name,comment,default_value,type"
		$URI = "https://$Gridmaster/wapi/$Global:WapiVersion/extensibleattributedef?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($Name){
			$URI += "name$Operator$Name&"
		}
		If ($Type){
			$URI += "type=$($Type.ToUpper())&"
		}
		If ($comment){
			$URI += "comment$operator$comment&"
		}
        If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
		Foreach ($item in $return){
			$output += [IB_ExtAttrsDef]::New($gridmaster,$credential,$Item.name,$Item.type,$Item.comment,$Item.default_value,$Item._ref)
		}
        return $output
    }
    #endregion
    #region Set method
    hidden [void]Set(
        [String]$Name,
		[String]$Type,
		[String]$Comment,
		[String]$DefaultValue
    )
	{
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyHashTable = $null
        $bodyHashTable+=@{name=$Name}
        $bodyHashTable+=@{type=$Type.ToUpper()}
        $bodyHashTable+=@{comment=$comment}
		$bodyHashTable+=@{default_value=$DefaultValue}
        If ($bodyHashTable){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $($bodyHashTable | ConvertTo-Json) -ContentType application/json -Credential $this.Credential
			if ($return) {
				$this._ref = $return
				$this.type = $Type
				$this.comment = $Comment
				$this.defaultvalue = $DefaultValue
			}
		}
    }
    #endregion
#endregion
#region Constructors
    IB_ExtAttrsDef(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[String]$Type,
		[String]$Comment,
		[String]$DefaultValue,
		[String]$_ref
    ){
        $this.Name         = $Name
        $this.Comment      = $Comment
        $this._ref         = $_ref
        $this.gridmaster   = $Gridmaster
        $this.credential   = $Credential
		$this.type         = $Type
		$this.DefaultValue = $DefaultValue
    }
#endregion
}
Class IB_FixedAddress : IB_ReferenceObject {
    ##Properties
    [String]$Name
    [IPAddress]$IPAddress
    [String]$Comment
    [String]$NetworkView
	[String]$MAC
	[Object]$ExtAttrib
#region Methods
#region Create method
    static [IB_FixedAddress] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
        [IPAddress]$IPAddress,
        [String]$Comment,
        [String]$NetworkView,
		[String]$MAC
    ){
        $URIString = "https://$GridMaster/wapi/$Global:WapiVersion/fixedaddress"
        $bodyhashtable = @{ipv4addr=$IPAddress}
        $BodyHashTable += @{name=$Name}
        $bodyhashtable += @{comment=$comment}
        If ($networkview){$bodyhashtable += @{network_view = $NetworkView}}
		$BodyHashTable += @{mac = $MAC}
		If (($MAC -eq '00:00:00:00:00:00') -or ($MAC.Length -eq 0)){
			$bodyHashTable += @{match_client='RESERVED'}
		} else {
			$bodyHashTable += @{match_client='MAC_ADDRESS'}
		}

        $return = Invoke-RestMethod -Uri $URIString -Method Post -Body $BodyHashTable -Credential $Credential
        return [IB_FixedAddress]::Get($GridMaster,$Credential,$return)
        
    }
    #endregion
    #region Get methods
	static [IB_FixedAddress] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "extattrs,name,ipv4addr,comment,network_view,mac"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
        If ($Return) {
			return [IB_FixedAddress]::New($return.name,
										  $return.ipv4addr,
										  $return.comment,
										  $return._ref,
										  $return.network_view,
										  $return.mac,
										  $Gridmaster,
										  $Credential,
										  $($return.extattrs | Convertto-ExtAttrsArray))
		} else {
			return $Null
		}
	}
	static [IB_FixedAddress[]] Get(
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[IPAddress]$IPAddress,
		[String]$MAC,
		[String]$Comment,
		[String]$ExtAttribFilter,
		[String]$NetworkView,
		[Bool]$Strict,
		[Int]$MaxResults
	){
		$ReturnFields = "extattrs,name,ipv4addr,comment,network_view,mac"
		$URI = "https://$gridmaster/wapi/$Global:WapiVersion/fixedaddress?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($IPAddress){
			$URI += "ipv4addr=$($IPAddress.IPAddressToString)&"
		}
		If ($MAC){
			$URI += "mac=$mac&"
		}
		If ($Comment){
			$URI += "comment$operator$comment&"
		}
		If ($ExtAttribFilter){
			$URI += SearchStringToIBQuery -searchstring $ExtAttribFilter
		}
		If ($NetworkView){
			$URI += "network_view=$NetworkView&"
		}
		If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
        Foreach ($item in $return){
            $output += [IB_FixedAddress]::New($item.name,
											  $item.ipv4addr,
											  $item.comment,
											  $item._ref,
											  $item.network_view,
											  $item.mac,
											  $Gridmaster,
											  $Credential,
											  $($item.extattrs | convertto-extAttrsArray))
        }
        return $output
	}
    #endregion
    #region Set method
    hidden [Void] Set(
        [String]$Name,
        [String]$Comment,
		[String]$MAC
    ){
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyHashTable = $null
        $bodyHashTable+=@{name=$Name}
        $bodyHashTable+=@{comment=$comment}
		$bodyHashTable+=@{mac=$MAC}
		If ($MAC -eq "00:00:00:00:00:00"){
			$bodyHashTable+=@{match_client='RESERVED'}
		} else {
			$bodyHashTable+=@{match_client='MAC_ADDRESS'}
		}
        If ($bodyHashTable){
			$return = Invoke-RestMethod -Uri $URIString -Method Put -Body $($bodyHashTable | ConvertTo-Json) -ContentType application/json -Credential $this.Credential
			if ($return) {
				$this._ref = $return
				$this.name = $Name
				$this.comment = $Comment
				$this.MAC = $MAC
			}
		}
    }
    #endregion
	#region AddExtAttrib method
	hidden [void] AddExtAttrib (
		[String]$Name,
		[String]$Value
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $Name -Value $(New-object psobject -Property @{value=$Value})
		$ExtAttr = new-object psobject -Property @{$Name=$(get-variable $Name | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs+"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_FixedAddress]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
	#region RemoveExtAttrib method
	hidden [void] RemoveExtAttrib (
		[String]$ExtAttrib
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $ExtAttrib -Value $(New-object psobject -Property @{})
		$ExtAttr = new-object psobject -Property @{$extattrib=$(get-variable $ExtAttrib | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs-"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_FixedAddress]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
	#endregion
#endregion
#region Constructors
    IB_FixedAddress(
        [String]$Name,
        [IPAddress]$IPAddress,
		[String]$Comment,
        [String]$_ref,
        [String]$NetworkView,
		[String]$MAC,
        [String]$Gridmaster,
        [PSCredential]$Credential,
		[Object]$ExtAttrib
    ){
        $this.Name         = $Name
		$this.IPAddress    = $IPAddress
        $this.Comment      = $Comment
        $this._ref         = $_ref
        $this.networkview  = $NetworkView
		$this.MAC          = $MAC
        $this.gridmaster   = $Gridmaster
        $this.credential   = $Credential
		$this.ExtAttrib    = $ExtAttrib
    }
#endregion
}
Class IB_Network : IB_ReferenceObject {
    ##Properties
    [String]$Network
    [String]$NetworkView
    [String]$NetworkContainer
    [String]$Comment
    [Object]$ExtAttrib
#region Create Method
    static [IB_Network] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Network,
        [String]$NetworkView,
        [String]$Comment
    ){
        $URIString = "https://$Gridmaster/wapi/$Global:WapiVersion/network"
        $bodyhashtable = @{network=$Network}
        If ($comment){$bodyhashtable += @{comment=$Comment}}
        If ($NetworkView){$bodyhashtable += @{network_view = $NetworkView}}
        $return = Invoke-RestMethod -uri $URIString -Method Post -Body $bodyhashtable -Credential $Credential
        return [IB_Network]::Get($Gridmaster,$Credential,$return)
    }
#region Get Methods
    static [IB_Network] Get (
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [String]$_ref
    ){
        $ReturnFields = "extattrs,network,network_view,network_container,comment"
        $URIstring = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
        $Return = Invoke-RestMethod -Uri $URIstring -Credential $Credential
        If ($Return){
            return [IB_Network]::New($Return.Network,
                                         $return.Network_View,
                                         $return.Network_Container,
                                         $return.Comment,
                                         $($return.extattrs | convertto-ExtAttrsArray),
                                         $return._ref,
                                         $Gridmaster,
                                         $Credential
            )
        } else {
            return $Null
        }
    }
    static [IB_Network[]] Get(
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [String]$Network,
        [String]$NetworkView,
        [String]$NetworkContainer,
        [String]$Comment,
        [String]$ExtAttribFilter,
        [bool]$Strict,
        [Int]$MaxResults
    ){
        $ReturnFields = "extattrs,network,network_view,network_container,comment"
        $URI = "https://$gridmaster/wapi/$Global:WapiVersion/network?"
        If ($Strict){$Operator = "="} else {$Operator = "~="}
        If ($Network){
            $URI += "network$Operator$Network&"
        }
        If ($NetworkView){
            $URI += "network_view=$Networkview&"
        }
        If ($NetworkContainer){
            $URI += "network_container=$NetworkContainer&"
        }
        If ($comment){
            $URI += "comment`:$operator$comment&"
        }
        If ($ExtAttribFilter){
            $URI += SearchStringtoIBQuery -searchstring $ExtAttribFilter
        }
        If ($MaxResults){
            $URI += "_max_results=$MaxResults&"
        }
        $URI += "_return_fields=$ReturnFields"
        write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -Uri $URI -Credential $Credential
        $output = @()
        Foreach ($Item in $Return){
            $output += [IB_Network]::New($item.Network,
                                         $item.Network_View,
                                         $item.Network_Container,
                                         $item.Comment,
                                         $($item.extattrs | convertto-ExtAttrsArray),
                                         $item._ref,
                                         $Gridmaster,
                                         $Credential
            )
        }
        return $Output
    }
#region Set Method
    hidden [void]Set (
        [String]$Comment
    ){
        $URIString = "https://$($this.Gridmaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyhashtable = @{comment=$Comment}
        If ($bodyhashtable){
            $return = Invoke-RestMethod -uri $URIString -method Put -body $($bodyhashtable | convertto-json) -contenttype application/json -Credential $this.Credential
            If ($return) {
                $this._ref = $return
                $this.comment = $Comment
            }
        }
    }
#region AddExtAttrib method
	hidden [void] AddExtAttrib (
		[String]$Name,
		[String]$Value
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $Name -Value $(New-object psobject -Property @{value=$Value})
		$ExtAttr = new-object psobject -Property @{$Name=$(get-variable $Name | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs+"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_Network]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
#region RemoveExtAttrib method
	hidden [void] RemoveExtAttrib (
		[String]$ExtAttrib
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $ExtAttrib -Value $(New-object psobject -Property @{})
		$ExtAttr = new-object psobject -Property @{$extattrib=$(get-variable $ExtAttrib | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs-"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_Network]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
#region NextAvailableIP method
    hidden [String[]] GetNextAvailableIP (
        [String[]]$Exclude,
        [uint32]$Count
    ){
        $URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)?_function=next_available_ip"
        $bodyhashtable = $null
        if ($count){$bodyhashtable += @{num = $count}}
        If ($Exclude){$bodyhashtable += @{exclude = $Exclude}}
        If ($bodyhashtable){
            return Invoke-RestMethod -uri $URIString -method Post -body $($bodyhashtable | convertto-json) -contenttype application/json -Credential $this.Credential
        } else {
            return $Null
        }
    }
#region Constructors
    IB_Network(
        [String]$Network,
        [String]$NetworkView,
        [String]$NetworkContainer,
        [String]$Comment,
        [object]$ExtAttrib,
        [String]$_ref,
        [String]$Gridmaster,
        [PSCredential]$Credential
    ){
        $this.Network          = $Network
        $this.NetworkView      = $NetworkView
        $this.NetworkContainer = $NetworkContainer
        $this.Comment          = $Comment
        $this.ExtAttrib        = $ExtAttrib
        $this._ref             = $_ref
        $this.Gridmaster       = $Gridmaster
        $this.Credential       = $Credential
    }
}
Class IB_networkview : IB_ReferenceObject {
    ##Properties
    [String]$name
    [bool]$is_default
    [String]$Comment
	[Object]$ExtAttrib
    ##methods
    [String] ToString () {
        return $this.name
    }
	static [IB_NetworkView] Create(
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$Name,
		[String]$Comment
	){
		$URIString = "https://$Gridmaster/wapi/$Global:WapiVersion/networkview"
		$bodyhashtable = @{name=$Name}
		If ($Comment){$bodyhashtable += @{comment=$Comment}}
		$Return = Invoke-RestMethod -uri $URIString -Method Post -body $bodyhashtable -Credential $Credential
		return [IB_NetworkView]::Get($gridmaster,$Credential,$return)
	}
	static [IB_networkview] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "extattrs,name,is_default,comment"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
		If ($Return) {
			return [IB_networkview]::New($Return.name,
										 $Return.is_default, 
										 $Return.comment, 
										 $Return._ref, 
										 $gridmaster, 
										 $credential,
										 $($return.extattrs | ConvertTo-ExtAttrsArray))
		} else {
			return $Null
		}
				
	}
    static [IB_networkview[]] Get(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[String]$Is_Default,
		[String]$Comment,
		[String]$ExtAttribFilter,
        [Bool]$Strict,
        [Int]$MaxResults
    ){
		$ReturnFields = "extattrs,name,is_default,comment"
		$URI = "https://$Gridmaster/wapi/$Global:WapiVersion/networkview?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($Name){
			$URI += "name$Operator$Name&"
		}
		If ($Is_Default){
			$URI += "is_default=$Is_Default&"
		}
		If ($comment){
			$URI += "comment$operator$comment&"
		}
 		If ($ExtAttribFilter){
			$URI += SearchStringToIBQuery -searchstring $ExtAttribFilter
		}
       If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
        Foreach ($item in $return){
                $output += [IB_networkview]::New($item.name,
												 $Item.is_default,
												 $item.comment,
												 $item._ref,
												 $Gridmaster,
												 $credential,
												 $($item.extattrs | ConvertTo-ExtAttrsArray))
        }
        return $output
    }
#region Set Method
    hidden [void]Set (
		[String]$Name,
        [String]$Comment
    ){
        $URIString = "https://$($this.Gridmaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyhashtable = $Null
		$bodyhashtable += @{name=$Name}
		$bodyhashtable += @{comment=$Comment}
        If ($bodyhashtable){
            $return = Invoke-RestMethod -uri $URIString -method Put -body $($bodyhashtable | convertto-json) -contenttype application/json -Credential $this.Credential
            If ($return) {
                $this._ref = $return
				$this.name = $Name
                $this.comment = $Comment
            }
        }
    }
    ##constructors
    #These have to exist in order for the List method to create the object instance
    IB_networkview(
        [String]$name,
        [bool]$is_default,
        [string]$comment,
        [string]$_ref,
		[String]$Gridmaster,
        [PSCredential]$Credential,
 		[Object]$ExtAttrib
   ){
        $this.name       = $name
        $this.is_default = $is_default
        $this.Comment    = $comment
        $this._ref       = $_ref
		$this.Gridmaster = $Gridmaster
		$this.Credential = $Credential
		$this.extattrib  = $ExtAttrib
    }
}
Class IB_View : IB_ReferenceObject {
    ##Properties
    [String]$name
    [bool]$is_default
    [String]$Comment
	[Object]$ExtAttrib
    ##methods
    [String] ToString () {
        return $this.name
    }
	static [IB_View] Create(
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$Name,
		[String]$Comment
	){
		$URIString = "https://$Gridmaster/wapi/$Global:WapiVersion/view"
		$bodyhashtable = @{name=$Name}
		If ($Comment){$bodyhashtable += @{comment=$Comment}}
		$Return = Invoke-RestMethod -uri $URIString -Method Post -body $bodyhashtable -Credential $Credential
		return [IB_View]::Get($gridmaster,$Credential,$return)
	}
	static [IB_View] Get (
		[String]$Gridmaster,
		[PSCredential]$Credential,
		[String]$_ref
	) {
		$ReturnFields = "extattrs,name,is_default,comment"
		$URIString = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
		$return = Invoke-RestMethod -Uri $URIString -Credential $Credential
		If ($Return) {
			return [IB_View]::New($Return.name, 
								  $Return.is_default, 
								  $Return.comment, 
								  $Return._ref, 
								  $gridmaster, 
								  $credential,
								  $($return.extattrs | ConvertTo-ExtAttrsArray))
		} else {
			return $Null
		}
				
	}


    static [IB_View[]] Get(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$Name,
		[String]$Is_Default,
		[String]$Comment,
		[String]$ExtAttribFilter,
        [Bool]$Strict,
        [Int]$MaxResults
    ){
		$ReturnFields = "extattrs,name,is_default,comment"
		$URI = "https://$Gridmaster/wapi/$Global:WapiVersion/view?"
		If ($Strict){$Operator = ":="} else {$Operator = "~:="}
		If ($Name){
			$URI += "name$Operator$Name&"
		}
		If ($Is_Default){
			$URI += "is_default=$Is_Default&"
		}
		If ($comment){
			$URI += "comment$operator$comment&"
		}
		If ($ExtAttribFilter){
			$URI += SearchStringToIBQuery -searchstring $ExtAttribFilter
		}
        If ($MaxResults){
			$URI += "_max_results=$MaxResults&"
		}
		$URI += "_return_fields=$ReturnFields"
		write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -URI $URI -Credential $Credential
        $output = @()
        Foreach ($item in $return){
                $output += [IB_View]::New($item.name,
										  $Item.is_default,
										  $item.comment,
										  $item._ref,
										  $Gridmaster,
										  $credential,
										  $($item.extattrs | ConvertTo-ExtAttrsArray))
        }
        return $output
    }
#region Set Method
    hidden [void]Set (
		[String]$Name,
        [String]$Comment
    ){
        $URIString = "https://$($this.Gridmaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyhashtable = $null
		$bodyhashtable += @{name=$Name}
		$bodyhashtable += @{comment=$Comment}
        If ($bodyhashtable){
            $return = Invoke-RestMethod -uri $URIString -method Put -body $($bodyhashtable | convertto-json) -contenttype application/json -Credential $this.Credential
            If ($return) {
                $this._ref = $return
				$this.name = $Name
                $this.comment = $Comment
            }
        }
    }
#constructors
    #These have to exist in order for the List method to create the object instance
    IB_View(
        [String]$name,
        [bool]$is_default,
        [string]$comment,
        [string]$_ref,
		[String]$Gridmaster,
        [PSCredential]$Credential,
		[Object]$ExtAttrib
    ){
        $this.name       = $name
        $this.is_default = $is_default
        $this.Comment    = $comment
        $this._ref       = $_ref
		$this.Gridmaster = $Gridmaster
		$this.Credential = $Credential
		$this.extattrib  = $ExtAttrib
    }
}
Class IB_ZoneAuth : IB_ReferenceObject {
    ##Properties
    [String]$FQDN
    [String]$View
    [String]$ZoneFormat
    [String]$Comment
    [Object]$ExtAttrib
#region Create Method
    static [IB_ZoneAuth] Create(
        [String]$GridMaster,
        [PSCredential]$Credential,
        [String]$FQDN,
        [String]$View,
        [String]$ZoneFormat,
        [String]$Comment
    ){
        $URIString = "https://$Gridmaster/wapi/$Global:WapiVersion/zone_auth"
        $bodyhashtable = @{fqdn=$fqdn}
        If ($comment){$bodyhashtable += @{comment=$Comment}}
        If ($View){$bodyhashtable += @{view = $View}}
        If ($ZoneFormat){$bodyhashtable += @{zone_format = $zoneformat.ToUpper()}}
        $return = Invoke-RestMethod -uri $URIString -Method Post -Body $bodyhashtable -Credential $Credential
        return [IB_ZoneAuth]::Get($Gridmaster,$Credential,$return)
    }
#region Get Methods
    static [IB_ZoneAuth] Get (
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [String]$_ref
    ){
        $ReturnFields = "extattrs,fqdn,view,zone_format,comment"
        $URIstring = "https://$gridmaster/wapi/$Global:WapiVersion/$_ref`?_return_fields=$ReturnFields"
        $Return = Invoke-RestMethod -Uri $URIstring -Credential $Credential
        If ($Return){
            return [IB_ZoneAuth]::New($Return.FQDN,
                                         $return.view,
                                         $return.zone_format,
                                         $return.Comment,
                                         $($return.extattrs | convertto-ExtAttrsArray),
                                         $return._ref,
                                         $Gridmaster,
                                         $Credential
            )
        } else {
            return $Null
        }
    }
    static [IB_ZoneAuth[]] Get(
        [String]$Gridmaster,
        [PSCredential]$Credential,
        [String]$FQDN,
        [String]$View,
        [String]$ZoneFormat,
        [String]$Comment,
        [String]$ExtAttribFilter,
        [bool]$Strict,
        [Int]$MaxResults
    ){
        $ReturnFields = "extattrs,fqdn,view,zone_format,comment"
        $URI = "https://$gridmaster/wapi/$Global:WapiVersion/zone_auth?"
        If ($Strict){$Operator = "="} else {$Operator = "~="}
        If ($FQDN){
            $URI += "fqdn$Operator$fqdn&"
        }
        If ($View){
            $URI += "view=$view&"
        }
        If ($ZoneFormat){
            $URI += "zone_format=$($ZoneFormat.ToUpper())&"
        }
        If ($comment){
            $URI += "comment`:$operator$comment&"
        }
        If ($ExtAttribFilter){
            $URI += SearchStringtoIBQuery -searchstring $ExtAttribFilter
        }
        If ($MaxResults){
            $URI += "_max_results=$MaxResults&"
        }
        $URI += "_return_fields=$ReturnFields"
        write-verbose "URI String:  $URI"
        $return = Invoke-RestMethod -Uri $URI -Credential $Credential
        $output = @()
        Foreach ($Item in $Return){
            $output += [IB_ZoneAuth]::New($item.fqdn,
                                         $item.View,
                                         $item.zone_format,
                                         $item.Comment,
                                         $($item.extattrs | convertto-ExtAttrsArray),
                                         $item._ref,
                                         $Gridmaster,
                                         $Credential
            )
        }
        return $Output
    }
#region Set Method
    hidden [void]Set (
        [String]$Comment
    ){
        $URIString = "https://$($this.Gridmaster)/wapi/$Global:WapiVersion/$($this._ref)"
        $bodyhashtable = @{comment=$Comment}
        If ($bodyhashtable){
            $return = Invoke-RestMethod -uri $URIString -method Put -body $($bodyhashtable | convertto-json) -contenttype application/json -Credential $this.Credential
            If ($return) {
                $this._ref = $return
                $this.comment = $Comment
            }
        }
    }
#region AddExtAttrib method
	hidden [void] AddExtAttrib (
		[String]$Name,
		[String]$Value
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $Name -Value $(New-object psobject -Property @{value=$Value})
		$ExtAttr = new-object psobject -Property @{$Name=$(get-variable $Name | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs+"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_ZoneAuth]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
#region RemoveExtAttrib method
	hidden [void] RemoveExtAttrib (
		[String]$ExtAttrib
	){
		$URIString = "https://$($this.GridMaster)/wapi/$Global:WapiVersion/$($this._ref)"
		New-Variable -name $ExtAttrib -Value $(New-object psobject -Property @{})
		$ExtAttr = new-object psobject -Property @{$extattrib=$(get-variable $ExtAttrib | Select-Object -ExpandProperty Value)}
		$body = new-object psobject -Property @{"extattrs-"=$extattr}
		$JSONBody = $body | ConvertTo-Json
		If ($JSONBody){
			$Return = Invoke-RestMethod -Uri $URIString -Method Put -Body $JSONBody -ContentType application/json -Credential $this.Credential
			If ($Return){
				$record = [IB_ZoneAuth]::Get($this.gridmaster,$this.credential,$return)
				$this.ExtAttrib = $record.extAttrib
			}
		}
	}
#region Constructors
    IB_ZoneAuth(
        [String]$fqdn,
        [String]$View,
        [String]$ZoneFormat,
        [String]$Comment,
        [object]$ExtAttrib,
        [String]$_ref,
        [String]$Gridmaster,
        [PSCredential]$Credential
    ){
        $this.fqdn       = $fqdn
        $this.View       = $view
        $this.zoneformat = $zoneformat
        $this.Comment    = $Comment
        $this.ExtAttrib  = $ExtAttrib
        $this._ref       = $_ref
        $this.Gridmaster = $Gridmaster
        $this.Credential = $Credential
    }
}
<#
.Synopsis
	Add-IBExtensibleAttribute adds or updates an extensible attribute to an existing infoblox record.
.DESCRIPTION
	Updates the provided infoblox record with an extensible attribute as defined in the ExtensibleAttributeDefinition of the Infoblox.  If the extensible attribute specified already exists the value will be updated.  A valid infoblox object must be provided either through parameter or pipeline.  Pipeline supports multiple objects, to allow adding/updating the extensible attribute on multiple records at once.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the Infoblox object.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_xxx representing the Infoblox object.  This parameter is typically for passing an object in from the pipeline, likely from Get-DNSARecord.
.PARAMETER EAName
	The name of the extensible attribute to add to the provided infoblox object.  This extensible attribute must already be defined on the Infoblox.
.PARAMETER EAValue
	The value to set the specified extensible attribute to.  Provided value must meet the data type criteria specified by the extensible attribute definition.
.PARAMETER Passthru
	Switch parameter to return the provided object(x) with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Add-IBExtensibleAttribute -gridmaster $gridmaster -credential $credential -_Ref 'record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default' -EAName Site -EAValue Corp
	
	This example create a new extensible attribute for 'Site' with value of 'Corp' on the provided extensible attribute
.EXAMPLE
	Get-DNSARecord  -gridmaster $gridmaster -credential $credential -_Ref 'record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default' | `
		Add-IBExtensibleAttribute -EAName Site -EAValue DR
	
	This example retrieves the DNS record using Get-DNSARecord, then passes that object through the pipeline to Add-IBExtensibleAttribute, which updates the previously created extensible attribute 'Site' to value 'DR'
.EXAMPLE
	Get-IBFixedAddress -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'} | Add-IBExtensibleAttribute -EAName Site -EAValue NewSite
	
	This example retrieves all Fixed Address objects with a defined Extensible attribute of 'Site' with value 'OldSite' and updates the value to 'NewSite'
#>
Function Add-IBExtensibleAttribute {
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [object[]]$Record,

		[Parameter(Mandatory=$True)]
		[ValidateNotNullorEmpty()]
		[String]$EAName,

		[Parameter(Mandatory=$True)]
		[ValidateNotNullorEmpty()]
		[String]$EAValue,

		[Switch]$Passthru
	)
	BEGIN{        
		$FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
	}
    PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byRef'){
			Write-Verbose "$FunctionName`:  Refstring passed, querying infoblox for record"
            $Record = [IB_DNSARecord]::Get($Gridmaster,$Credential,$_Ref)
			$Record = Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref $_Ref
            If ($Record){
 				Write-Verbose "$FunctionName`: object found, passing to cmdlet through pipeline"
               $Record | Add-IBExtensibleAttribute -EAName $EAName -EAValue $EAValue -Passthru:$Passthru
            }
			
        } else {
			Foreach ($Item in $Record){
			# add code to validate ea data against extensible attribute definition on infoblox.
				If ($pscmdlet.ShouldProcess($Item)) {
					write-verbose "$FunctionName`:  Adding EA $eaname to $item"
					$Item.AddExtAttrib($EAName,$EAValue)
					If ($Passthru) {
						Write-Verbose "$FunctionName`:  Passthru specified, returning dns object as output"
						return $Item
					}

				}
			}
		}
	}
	END{}
}
<#
.Synopsis
	Performs a full search of all Infoblox records matching the supplied value.
.DESCRIPTION
	Performs a full search of all Infoblox records matching the supplied value.  Returns defined objects for defined record types, and IB_ReferenceObjects for undefined types.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER IPAddress
	The IP Address to search for.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER SearchString
	A string to search for.  Will return any record with the matching string anywhere in a matching string property.  Use with -Strict to match only the exact string.
.PARAMETER Strict
	A switch to specify whether the search of the Name field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER RecordType
	A filter for record searching.  By default this cmdlet will search all record types.  Use this parameter to search for only a specific record type.  Can only be used with a string search.  Note this parameter is not validated, so value must be the correct syntax for the infoblox to retrieve it.
.EXAMPLE
	Find-IBRecord -Gridmaster $Gridmaster -Credential $Credential -IPAddress '192.168.101.1'

	This example retrieves all records with IP Address of 192.168.101.1
.EXAMPLE
	Find-IBRecord -Gridmaster $Gridmaster -Credential $Credential -SearchString 'Test' -Strict

	This example retrieves all records with the exact name 'Test'
.EXAMPLE
	Find-IBRecord -Gridmaster $Gridmaster -Credential $Credential -SearchString 'Test' -RecordType 'record:a'

	This example retrieves all dns a records that have 'test' in the name.
.EXAMPLE
	Find-IBRecord -Gridmaster $Gridmaster -Credential $Credential -RecordType 'fixedaddress'

	This example retrieves all fixedaddress records in the infoblox database
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_FixedAddress
	IB_DNSARecord
	IB_DNSCNameRecord
	IB_DNSPTRRecord
	IB_ReferenceObject
#>
Function Find-IBRecord {
    [CmdletBinding(DefaultParameterSetName = 'globalSearchbyIP')]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='globalSearchbyString')]
        [String]$SearchString,

		[Parameter(ParameterSetName='globalSearchbyString')]
		[String]$RecordType,

        [Parameter(ParameterSetName='globalSearchbyString')]
        [Switch]$Strict,

        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='globalSearchbyIP')]
        [IPAddress]$IPAddress,

		[String]$Type,

        [Int]$MaxResults

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
		get-ibview -Gridmaster $Gridmaster -Credential $Credential -Type dnsview | out-null
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        if ($pscmdlet.ParameterSetName -eq 'globalSearchbyString'){
			If ($Strict){
				$uribase = "https://$gridmaster/wapi/$Global:WapiVersion/search?search_string:="

			} else {
				$uribase = "https://$gridmaster/wapi/$Global:WapiVersion/search?search_string~:="

			}
		} elseif ($pscmdlet.ParameterSetName -eq 'globalSearchbyIP'){
			$uribase = "https://$gridmaster/wapi/$Global:WapiVersion/search?address="
		}
		
	}


    PROCESS{
		If ($SearchString){
			$URI = "$uribase$SearchString"
			If ($RecordType){$URI += "&objtype=$recordtype"}
		} elseif ($IPAddress){
			$URI = "$uribase$($ipaddress.IPAddresstoString)"
		}
		If ($MaxResults){
			$Uri += "&_max_results=$MaxResults"
		}
		If ($Type){
			$Uri += "&objtype=$Type"
		}
		Write-verbose "$FunctionName`:  URI String`:  $uri"

		$output = Invoke-RestMethod -Uri $URI -Credential $Credential
		write-verbose "$FunctionName`:  Found the following objects:"
		foreach ($item in $output){
			write-verbose "`t`t$($item._ref)"
		}
		Foreach ($item in $output){
			Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_ref $item._ref
		}

    }
    END{}
}
<#
.Synopsis
	Get-IBDNSARecord retreives objects of type DNSARecord from the Infoblox database.
.DESCRIPTION
	Get-IBDNSARecord retreives objects of type DNSARecord from the Infoblox database.  Parameters allow searching by Name, IPAddress, View, Zone or Comment  Also allows retrieving a specific record by reference string.  Returned object is of class type DNSARecord.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The dns name to search for.  Can be fqdn or partial name match depending on use of the -Strict switch
.PARAMETER IPAddress
	The IP Address to search for.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER Zone
	The DNS zone to search for records in.  Note that specifying a zone will also restrict the searching to a specific view.  The default view will be used if none is specified.
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER View
	The Infoblox view to search for records in.  The provided value must match a valid view on the Infoblox.  Note that if the zone parameter is used for searching results are narrowed to a particular view.  Otherwise, searches are performed across all views.
.PARAMETER Comment
	A string to search for in the comment field of the DNS record.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the name or comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -IPAddress '192.168.101.1'

	This example retrieves all DNS records with IP Address of 192.168.101.1
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all DNS records with the exact comment 'test comment'
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -_Ref 'record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default'

	This example retrieves the single DNS record with the assigned reference string
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -name Testrecord.domain.com | Remove-IBDNSARecord

	This example retrieves the dns record with name testrecord.domain.com, and deletes it from the infoblox database.
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSARecord -comment 'new comment'
	
	This example retrieves all dns records with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBDNSARecord -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'}

	This example retrieves all dns records with an extensible attribute defined for 'Site' with value of 'OldSite'
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSARecord
#>
Function Get-IBDNSARecord {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Name,

		[Parameter(ParameterSetName='byQuery')]
		[IPAddress]$IPAddress,

		[Parameter(ParameterSetName='byQuery')]
		[String]$View,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Zone,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,

		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for A Records"
			[IB_DNSARecord]::Get($Gridmaster,$Credential,$Name,$IPAddress,$Comment,$ExtAttributeQuery,$Zone,$View,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for A record with reference string $_ref"
			[IB_DNSARecord]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBDNSCNameRecord retreives objects of type DNSCNameRecord from the Infoblox database.
.DESCRIPTION
	Get-IBDNSCNameRecord retreives objects of type DNSCNameRecord from the Infoblox database.  Parameters allow searching by Name, Canonical, View, Zone or Comment  Also allows retrieving a specific record by reference string.  Returned object is of class type DNSCNameRecord.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The dns name to search for.  Can be fqdn or partial name match depending on use of the -Strict switch
.PARAMETER Canonical
	The canonical name to search for.  This is the record that the Alias(name) resolves to.  Can be fqdn or partial name match depending on use of the -Strict switch
.PARAMETER Zone
	The DNS zone to search for records in.  Note that specifying a zone will also restrict the searching to a specific view.  The default view will be used if none is specified.
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER View
	The Infoblox view to search for records in.  The provided value must match a valid view on the Infoblox.  Note that if the zone parameter is used for searching results are narrowed to a particular view.  Otherwise, searches are performed across all views.
.PARAMETER Comment
	A string to search for in the comment field of the DNS record.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the name, canonical or comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Canonical 'testrecord.domain.com'

	This example retrieves all DNS records with Canonical of testrecord.domain.com
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all DNS records with the exact comment 'test comment'
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref 'record:cname/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testalias.domain.com/default'

	This example retrieves the single DNS record with the assigned reference string
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -name testalias.domain.com | Remove-IBDNSCNameRecord

	This example retrieves the dns record with name testalias.domain.com, and deletes it from the infoblox database.
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSCNameRecord -comment 'new comment'
	
	This example retrieves all dns records with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Canonical 'oldserver.domain.com' -Strict | Set-IBDNSCNameRecord -canonical 'newserver.fqdn.com'

	This example retrieves all dns cname records pointing to an old server, and replaces the value with the fqdn of a new server.
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Canonical 'oldserver.domain.com' -Strict | Remove-IBDNSCNameRecord

	This example retrieves all dns cname records pointing to an old server, and deletes them.
.EXAMPLE
	Get-IBDNSCNameRecord -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'}

	This example retrieves all dns records with an extensible attribute defined for 'Site' with value of 'OldSite'
.INPUTS
	System.Net.Canonical[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSCNameRecord
#>
Function Get-IBDNSCNameRecord {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Name,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Canonical,

		[Parameter(ParameterSetName='byQuery')]
		[String]$View,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Zone,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,
        
		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for CName Records"
			[IB_DNSCNameRecord]::Get($Gridmaster,$Credential,$Name,$Canonical,$Comment,$ExtAttributeQuery,$Zone,$View,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for CName record with reference string $_ref"
			[IB_DNSCNameRecord]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBDNSPTRRecord retreives objects of type DNSPTRRecord from the Infoblox database.
.DESCRIPTION
	Get-IBDNSPTRRecord retreives objects of type DNSPTRRecord from the Infoblox database.  Parameters allow searching by Name, IPAddress, View, Zone or Comment  Also allows retrieving a specific record by reference string.  Returned object is of class type DNSPTRRecord.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The record name to search for.  This is usually something like '1.1.168.192.in-addr.arpa'.  To search for a hostname that the PTR record resolves to, use the PTRDName parameter.  Can be fqdn or partial name match depending on use of the -Strict switch
.PARAMETER PTRDName
	The hostname to search for.  Note this is not the name of the PTR record, but rather the name that the ptr record points to.  Can be fqdn or partial name match depending on use of the -Strict switch
.PARAMETER IPAddress
	The IP Address to search for.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER Zone
	The DNS zone to search for records in.  Note that specifying a zone will also restrict the searching to a specific view.  The default view will be used if none is specified.
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER View
	The Infoblox view to search for records in.  The provided value must match a valid view on the Infoblox.  Note that if the zone parameter is used for searching results are narrowed to a particular view.  Otherwise, searches are performed across all views.
.PARAMETER Comment
	A string to search for in the comment field of the DNS record.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the Name, PTRDname or comment fields should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -IPAddress '192.168.101.1'

	This example retrieves all DNS PTR records with IP Address of 192.168.101.1
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all DNS PTR records with the exact comment 'test comment'
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref 'record:ptr/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:1.1.168.192.in-addr.arpa/default'

	This example retrieves the single DNS PTR record with the assigned reference string
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -PTRDName Testrecord.domain.com | Remove-IBDNSPTRRecord

	This example retrieves the DNS PTR record with PTRDName testrecord.domain.com, and deletes it from the infoblox database.
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSPTRRecord -comment 'new comment'
	
	This example retrieves all DNS PTR records with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBDNSPTRRecord -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'}

	This example retrieves all dns records with an extensible attribute defined for 'Site' with value of 'OldSite'
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSPTRRecord
#>
Function Get-IBDNSPTRRecord {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Name,

		[Parameter(ParameterSetName='byQuery')]
		[IPAddress]$IPAddress,

		[Parameter(ParameterSetName='byQuery')]
		[String]$PTRDName,

		[Parameter(ParameterSetName='byQuery')]
		[String]$View,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Zone,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,
        
		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for PTR Records"
			[IB_DNSPTRRecord]::Get($Gridmaster,$Credential,$Name,$IPAddress,$PTRDName,$Comment,$ExtAttributeQuery,$Zone,$View,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for PTR record with reference string $_ref"
			[IB_DNSPTRRecord]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBDNSZone retreives objects of type DNSZone from the Infoblox database.
.DESCRIPTION
	Get-IBDNSZone retreives objects of type DNSZone from the Infoblox database.  Parameters allow searching by DNSZone, DNSZone view or comment.  Also allows retrieving a specific record by reference string.  Returned object is of class type IB_DNSZone.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER FQDN
	The fully qualified name of the DNSZone to search for.  Partial matches are supported.
.Parameter ZoneFormat
	The parent dns zone format to search by.  Will return any DNSZones of this type.  Valid values are:
        â€¢FORWARD
        â€¢IPV4
        â€¢IPV6
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER View
	The Infoblox DNS view to search for zones in.  The provided value must match a valid DNS view on the Infoblox.
.PARAMETER Comment
	A string to search for in the comment field of the dns zone record.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the dns zone record.  String is in format <recordtype>/<uniqueString>:<IPAddress>/<DNSZoneview>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBDNSZone -Gridmaster $Gridmaster -Credential $Credential -DNSZone 192.168.101.0/24

	This example retrieves the DNSZone object for subnet 192.168.101.0
.EXAMPLE
	Get-IBDNSZone -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all DNSZone objects with the exact comment 'test comment'
.EXAMPLE
	Get-IBDNSZone -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'}

	This example retrieves all DNSZone objects with an extensible attribute defined for 'Site' with value of 'OldSite'
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSZone
#>
Function Get-IBDNSZone {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(ParameterSetName='byQuery')]
        [String]$FQDN,
		
        [Parameter(ParameterSetName='byQuery')]
        [ValidateSet('Forward','ipv4','ipv6')]
        [String]$ZoneFormat,

		[Parameter(ParameterSetName='byQuery')]
		[String]$View,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,
        
		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for DNSZone Records"
			[IB_ZoneAuth]::Get($Gridmaster,$Credential,$FQDN,$View,$ZoneFormat,$Comment,$ExtAttributeQuery,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for DNSZone record with reference string $_ref"
			[IB_ZoneAuth]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBExtensibleAttributeDefinition retreives objects of type ExtAttrsDef from the Infoblox database.
.DESCRIPTION
	Get-IBExtensibleAttributeDefinition retreives objects of type ExtAttrsDef from the Infoblox database.  Extensible Attribute Definitions define the type of extensible attributes that can be attached to other records.  Parameters allow searching by Name, type, and commentAlso allows retrieving a specific record by reference string.  Returned object is of class type IB_ExtAttrsDef.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The attribute definition name to search for.  Can be full or partial name match depending on use of the -Strict switch
.PARAMETER Type
	The attribute value type to search for.  Valid values are:
        â€¢DATE
        â€¢EMAIL
        â€¢ENUM
        â€¢INTEGER
        â€¢STRING
        â€¢URL

.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER Comment
	A string to search for in the comment field of the extensible attribute definition.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the name or comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the extensible attribute definition.  String is in format <recordtype>/<uniqueString>:<Name>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -Name 'Site'

	This example retrieves all extensible attribute definitions with name beginning with the word Site
.EXAMPLE
	Get-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all extensible attribute definitions with the exact comment 'test comment'
.EXAMPLE
	Get-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -_Ref 'extensibleattributedef/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:extattr2'

	This example retrieves the single extensible attribute definition with the assigned reference string
.EXAMPLE
	Get-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -name extattr2 | Remove-IBRecord

	This example retrieves the extensibleattributedefinition with name extattr2, and deletes it from the infoblox database.  Note that some builtin extensible attributes cannot be deleted.
.EXAMPLE
	Get-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSARecord -comment 'new comment'
	
	This example retrieves all extensible attribute definitions with a comment of 'old comment' and replaces it with 'new comment'
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ExtAttrsDef
#>
Function Get-IBExtensibleAttributeDefinition {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Name,

		[Parameter(ParameterSetName='byQuery')]
        [ValidateSet('Date','Email','Enum','Integer','String','URL')]
		[String]$Type,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,

		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for extensible attribute definitions"
			[IB_extattrsdef]::Get($Gridmaster,$Credential,$Name,$Type,$Comment,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for extensible attribute definitions with reference string $_ref"
			[IB_extattrsdef]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBFixedAddress retreives objects of type FixedAddress from the Infoblox database.
.DESCRIPTION
	Get-IBFixedAddress retreives objects of type FixedAddress from the Infoblox database.  Parameters allow searching by ip address, mac address, network view or comment.  Also allows retrieving a specific record by reference string.  Returned object is of class type FixedAddress.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER IPAddress
	The IP Address to search for.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER MAC
	The MAC address to search for.  Colon separated format of 00:00:00:00:00:00 is required.
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER NetworkView
	The Infoblox network view to search for records in.  The provided value must match a valid network view on the Infoblox.
.PARAMETER Comment
	A string to search for in the comment field of the Fixed Address record.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the fixed address record.  String is in format <recordtype>/<uniqueString>:<IPAddress>/<networkview>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -IPAddress '192.168.101.1'

	This example retrieves all fixed address records with IP Address of 192.168.101.1
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all fixed address records with the exact comment 'test comment'
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -MAC '00:00:00:00:00:00' -comment 'Delete'

	This example retrieves all fixed address records with a mac address of all zeroes and the word 'Delete' anywhere in the comment text.
.EXAMPLE
	Get-IBFixedAddress -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'}

	This example retrieves all dns records with an extensible attribute defined for 'Site' with value of 'OldSite'
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_FixedAddress
#>
Function Get-IBFixedAddress {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

		[Parameter(ParameterSetName='byQuery')]
		[IPAddress]$IPAddress,

		[Parameter(ParameterSetName='byQuery')]
		[ValidatePattern('^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')]
		[String]$MAC,

		[Parameter(ParameterSetName='byQuery')]
		[String]$NetworkView,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,
        
		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type NetworkView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for FixedAddress Records"
			[IB_FixedAddress]::Get($Gridmaster,$Credential,$IPAddress,$MAC,$Comment,$ExtAttributeQuery,$NetworkView,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for A record with reference string $_ref"
			[IB_FixedAddress]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBNetwork retreives objects of type Network from the Infoblox database.
.DESCRIPTION
	Get-IBNetwork retreives objects of type Network from the Infoblox database.  Parameters allow searching by network, network view or comment.  Also allows retrieving a specific record by reference string.  Returned object is of class type IB_Network.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Network
	The IP Network to search for.  Standard IPv4 or CIDR notation applies.  Partial matches are supported.
.Parameter NetworkContainer
	The parent network to search by.  Will return any networks that are subnets of this value.  i.e. query for 192.168.0.0/16 will return 192.168.1.0/24, 192.168.2.0/24, etc.
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER NetworkView
	The Infoblox network view to search for records in.  The provided value must match a valid network view on the Infoblox.
.PARAMETER Comment
	A string to search for in the comment field of the Fixed Address record.  Will return any record with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the fixed address record.  String is in format <recordtype>/<uniqueString>:<IPAddress>/<networkview>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -network 192.168.101.0/24

	This example retrieves the network object for subnet 192.168.101.0
.EXAMPLE
	Get-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -comment 'Test Comment' -Strict

	This example retrieves all network objects with the exact comment 'test comment'
.EXAMPLE
	Get-IBNetwork -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'}

	This example retrieves all network objects with an extensible attribute defined for 'Site' with value of 'OldSite'
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_Network
#>
Function Get-IBNetwork {
	[CmdletBinding(DefaultParameterSetName = 'byQuery')]
	Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(ParameterSetName='byQuery')]
        [ValidateScript({If ($_ -match '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$') {
            $True
        } else {
            Throw "$_ is not a CIDR address"
        }})]
        [String]$Network,
		
        [Parameter(ParameterSetName='byQuery')]
        [ValidateScript({If ($_ -match '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$') {
            $True
        } else {
            Throw "$_ is not a CIDR address"
        }})]
        [String]$NetworkContainer,

		[Parameter(ParameterSetName='byQuery')]
		[String]$NetworkView,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,
        
		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
        [Switch]$Strict,

		[Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byref')]
		[String]$_ref,

        [Int]$MaxResults
	)
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type NetworkView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }
    }
	PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byQuery') {
			Write-Verbose "$FunctionName`:  Performing query search for Network Records"
			[IB_Network]::Get($Gridmaster,$Credential,$Network,$NetworkView,$NetworkContainer,$Comment,$ExtAttributeQuery,$Strict,$MaxResults)
		} else {
			Write-Verbose "$FunctionName`: Querying $gridmaster for network record with reference string $_ref"
			[IB_Network]::Get($Gridmaster, $Credential, $_ref)
		}
	}
	END{}
}
<#
.Synopsis
	Get-IBRecord retreives objects from the Infoblox database.
.DESCRIPTION
	Get-IBRecord retreives objects from the Infoblox database.  Queries the Infoblox database for records matching the provided reference string.  Returns defined objects for class-defined record types, and IB_ReferenceObjects for undefined types.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref 'record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default'

		Name	  : testrecord.domain.com
		IPAddress : 192.168.1.1
		Comment   : 'test record'
		View      : default
		TTL       : 1200
		Use_TTL   : True
		_ref      : record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default

	Description
	-----------
	This example retrieves the single DNS record with the assigned reference string
.EXAMPLE
	Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref 'network/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:192.168.1.0/default'

		_ref      : network/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:192.168.1.0/default

	Description
	-----------
	This example returns an IB_ReferenceObject object for the undefined object type.  The object exists on the infoblox and is valid, but no class is defined for it in the cmdlet class definition.
.EXAMPLE
	Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -name Testrecord.domain.com | Remove-IBDNSARecord

	This example retrieves the dns record with name testrecord.domain.com, and deletes it from the infoblox database.
.EXAMPLE
	Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSARecord -comment 'new comment'
	
	This example retrieves all dns records with a comment of 'old comment' and replaces it with 'new comment'
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSARecord
#>
Function Get-IBRecord{
    [CmdletBinding(DefaultParameterSetName='byObject')]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [ValidateNotNullorEmpty()]
        [String]$_Ref
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
		$return = Switch ($_ref.ToString().split('/')[0]) {
			'record:a' {[IB_DNSARecord]::Get($Gridmaster, $Credential, $_ref)}
			'record:ptr' {[IB_DNSPTRRecord]::Get($gridmaster, $Credential, $_ref)}
			'record:cname' {[IB_DNSCNameRecord]::Get($Gridmaster, $Credential, $_ref)}
			'fixedaddress' {[IB_FixedAddress]::Get($gridmaster, $Credential, $_ref)}
			'view' {[IB_View]::Get($gridmaster, $Credential, $_ref)}
			'networkview' {[IB_NetworkView]::Get($Gridmaster, $Credential, $_ref)}
			'extensibleattributedef' {]IB_ExtAttrsDef]::Get($Gridmaster, $credential, $_ref)}
			default {[IB_ReferenceObject]::Get($gridmaster, $Credential, $_ref)}
		}
		If ($Return){
			return $Return
		} else {
			return $Null
		}
	}
    END{}
}
<#
.Synopsis
	Get-IBView retreives objects of type View or network_view from the Infoblox database.
.DESCRIPTION
	Get-IBView retreives objects of type view or network_view from the Infoblox database.  Parameters allow searching by Name, Comment or status as default.  Search can target either DNS View or Network view, not both.  Also allows retrieving a specific record by reference string.  Returned object is of class type IB_View or IB_NetworkView.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Type
	Determines which class of object to search for.  DNSView searches for IB_View objects, where NetworkView searches for IB_Networkview objects.
.PARAMETER Name
	The view name to search for.  Can be full or partial name match depending on use of the -Strict switch
.PARAMETER MaxResults
	The maximum number of results to return from the query.  A positive value will truncate the results at the specified number.  A negative value will throw an error if the query returns more than the specified number.
.PARAMETER isDefault
	Search for views based on whether they are default or not.  If parameter is not specified both types will be returned.
.PARAMETER Comment
	A string to search for in the comment field of the view.  Will return any view with the matching string anywhere in the comment field.  Use with -Strict to match only the exact string in the comment.
.PARAMETER Strict
	A switch to specify whether the search of the name or comment field should be exact, or allow partial word searches or regular expression matching.
.PARAMETER _Ref
	The unique reference string representing the view.  String is in format <recordtype>/<uniqueString>:<Name>/<isDefault>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Get-IBView -Gridmaster $Gridmaster -Credential $Credential Type DNSView -IsDefault $True

	This example retrieves the dns view specified as default.
.EXAMPLE
	Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type NetworkView -comment 'default'

	This example retrieves any network views with the word 'default' in the comment
.EXAMPLE
	Get-IBView -Gridmaster $Gridmaster -Credential $Credential -_Ref 'networkview/ZGdzLm5ldHdvamtfdmlldyQw:Default/true'

	This example retrieves the single view with the assigned reference string
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_View
	IB_NetworkView
#>
Function Get-IBView {
    [CmdletBinding(DefaultParameterSetName='byQuery')]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(ParameterSetName='byQuery')]
        [String]$Name,

		[Parameter(ParameterSetName='byQuery')]
		[String]$Comment,

		[Parameter(ParameterSetname='byQuery')]
		[String]$ExtAttributeQuery,
        
		[Parameter(ParameterSetName='byQuery')]
		[Switch]$Strict,

		[Parameter(ParameterSetName='byQuery')]
		[ValidateSet('True','False')]
		[String]$IsDefault,

		[Parameter(ParameterSetName='byQuery')]
		[int]$MaxResults,

		[Parameter(Mandatory=$True,ParameterSetName='byQuery')]
		[ValidateSet('DNSView','NetworkView')]
		[String]$Type,

		[Parameter(Mandatory=$True,ParameterSetName='byRef')]
		[String]$_Ref
    )
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    write-verbose "$FunctionName`:  Beginning Function"
		Try {
			If ($pscmdlet.ParameterSetName -eq 'byRef'){
				Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_ref $_Ref
			} else {
				If ($Type -eq 'DNSView'){
					Write-Verbose "$Functionname`:  calling IB_View Get method with the following parameters`:"
					Write-Verbose "$FunctionName`:  $gridmaster,$credential,$name,$isDefault,$Comment,$Strict,$MaxResults"
					[IB_View]::Get($Gridmaster,$Credential,$Name,$IsDefault,$Comment,$ExtAttributeQuery,$Strict,$MaxResults)
				} else {
					Write-Verbose "$Functionname`:  calling IB_NetworkView Get method with the following parameters`:"
					Write-Verbose "$FunctionName`:  $gridmaster,$credential,$name,$isDefault,$Comment,$Strict,$MaxResults"
					[IB_NetworkView]::Get($Gridmaster,$Credential,$Name,$IsDefault,$Comment,$ExtAttributeQuery,$Strict,$MaxResults)
				}

			}
		} Catch {
			Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
		}
}
<#
.Synopsis
	New-IBDNSARecord creates an object of type DNSARecord in the Infoblox database.
.DESCRIPTION
	New-IBDNSARecord creates an object of type DNSARecord in the Infoblox database.  If creation is successful an object of type IB_DNSARecord is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The Name of the new dns record.  This should be a valid FQDN, and the infoblox should be authoritative for the provided zone.
.PARAMETER IPAddress
	The IP Address for the new dns record.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER View
	The Infoblox view to create the record in.  The provided value must match a valid view on the Infoblox, and the zone specified in the name parameter must be present in the specified view.  If no view is provided the default DNS view is used.
.PARAMETER Comment
	Optional comment field for the dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER TTL
	Optional parameter to specify a record-specific TTL.  If not specified the record inherits the Grid TTL
.EXAMPLE
	New-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -Name testrecord.domain.com -IPAddress 192.168.1.1

		Name      : testrecord.domain.com
		IPAddress : 192.168.1.1
		Comment   :
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testrecord.domain.com/default

	description
	-----------
	This example creates a dns record with no comment, in the default view, and no record-specific TTL
.EXAMPLE
	New-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -Name TestRecord2.domain.com -IPAddress 192.168.1.2 -comment 'new record' -view default -ttl 100

		Name      : testrecord2.domain.com
		IPAddress : 192.168.1.2
		Comment   : new record
		View      : default
		TTL       : 100
		Use_TTL   : True
		_ref      : record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:testrecord2.domain.com/default

	description
	-----------
	This example creates a dns record with a comment, in the default view, with a TTL of 100 to override the grid default
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSARecord
#>
Function New-IBDNSARecord {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Name,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [IPAddress]$IPAddress,

        [String]$View,

        [String]$Comment,

        [uint32]$TTL = 4294967295

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    PROCESS{
        If ($ttl -eq 4294967295){
            $use_ttl = $False
            $ttl = $Null
        } else {
            $use_TTL = $True
        }
        If ($pscmdlet.ShouldProcess($Name)){
            $output = [IB_DNSARecord]::Create($Gridmaster, $Credential, $Name, $IPAddress, $Comment, $View, $ttl, $use_ttl)
            $output
        }
    }
    END{}
}
<#
.Synopsis
	New-IBDNSCNameRecord creates an object of type DNSCNameRecord in the Infoblox database.
.DESCRIPTION
	New-IBDNSCNameRecord creates an object of type DNSCNameRecord in the Infoblox database.  If creation is successful an object of type IB_DNSCNameRecord is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The Name of the new dns record.  This should be a valid FQDN, and the infoblox should be authoritative for the provided zone.
.PARAMETER Canonical
	The 'pointer' or canonical value of the new dns record.  Should be a valid FQDN, but infoblox does not need any control or authority of the zone
.PARAMETER View
	The Infoblox view to create the record in.  The provided value must match a valid view on the Infoblox, and the zone specified in the Name parameter must be present in the specified view.  If no view is provided the default DNS view is used.
.PARAMETER Comment
	Optional comment field for the dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER TTL
	Optional parameter to specify a record-specific TTL.  If not specified the record inherits the Grid TTL
.EXAMPLE
	New-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Name testalias.domain.com -Canonical testrecord.domain.com

		Name      : testalias.domain.com
		Canonical : testrecord.domain.com
		Comment   :
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:cname/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testalias.domain.com/default

	description
	-----------
	This example creates a dns record with no comment, in the default view, and no record-specific TTL
.EXAMPLE
	New-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Name Testalias2.domain.com -canonical testrecord2.domain.com -comment 'new record' -view default -ttl 100

		Name      : testalias2.domain.com
		Canonical : testrecord2.domain.com
		Comment   : new record
		View      : default
		TTL       : 100
		Use_TTL   : True
		_ref      : record:cname/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:testalias2.domain.com/default

	description
	-----------
	This example creates a dns record with a comment, in the default view, with a TTL of 100 to override the grid default
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSCNameRecord
#>
Function New-IBDNSCNameRecord {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Name,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Canonical,

        [String]$View,

        [String]$Comment,

        [uint32]$TTL = 4294967295

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
             $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    PROCESS{
        If ($ttl -eq 4294967295){
            $use_ttl = $False
            $ttl = $Null
        } else {
            $use_TTL = $True
        }
        If ($pscmdlet.ShouldProcess($Name)){
            $output = [IB_DNSCNameRecord]::Create($Gridmaster, $Credential, $Name, $Canonical, $Comment, $View, $ttl, $use_ttl)
            $output
        }
    }
    
    END{}
}
<#
.Synopsis
	New-IBDNSPTRRecord creates an object of type DNSPTRRecord in the Infoblox database.
.DESCRIPTION
	New-IBDNSPTRRecord creates an object of type DNSPTRRecord in the Infoblox database.  If creation is successful an object of type IB_DNSPTRRecord is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER PTRDName
	The hostname for the record to resolve to.  This should be a valid FQDN.
.PARAMETER IPAddress
	The IP Address for the new dns record.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER View
	The Infoblox view to create the record in.  The provided value must match a valid view on the Infoblox, and the PTR zone inferred from the IP Address must be present in the specified view.  For Example, if the IP Address is 192.168.1.1, then the zone 2.168.192.in-addr.arpa must exist in the specified view.  If no view is provided the default DNS view is used.
.PARAMETER Comment
	Optional comment field for the dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER TTL
	Optional parameter to specify a record-specific TTL.  If not specified the record inherits the Grid TTL
.EXAMPLE
	New-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -PTRDName testrecord.domain.com -IPAddress 192.168.1.1

		Name      : 1.1.168.192.in-addr.arpa
		PTRDName  : testrecord.domain.com
		IPAddress : 192.168.1.1
		Comment   :
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:ptr/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:1.1.168.192.in-addr.arpa/default

	description
	-----------
	This example creates a dns record with no comment, in the default view, and no record-specific TTL
.EXAMPLE
	New-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -PTRDName TestRecord2.domain.com -IPAddress 192.168.1.2 -comment 'new record' -view default -ttl 100

		Name      : 2.1.168.192.in-addr.arpa
		PTRDName  : testrecord2.domain.com
		IPAddress : 192.168.1.2
		Comment   : new record
		View      : default
		TTL       : 100
		Use_TTL   : True
		_ref      : record:ptr/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:2.1.168.192.in-addr.arpa/default

	description
	-----------
	This example creates a dns record with a comment, in the default view, with a TTL of 100 to override the grid default
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSPTRRecord
#>
Function New-IBDNSPTRRecord {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$PTRDName,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [IPAddress]$IPAddress,

        [String]$View,

        [String]$Comment,

        [UInt32]$TTL = 4294967295

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    #OverloadDefinitions
    #-------------------
    #static IB_DNSPTRRecord Create(string GridMaster, pscredential Credential, string PTRDName, ipaddress IPAddress, string Comment, string view)

    PROCESS{
        If ($ttl -eq 4294967295){
            $use_ttl = $False
            $ttl = $Null
        } else {
            $use_TTL = $True
        }
        If ($pscmdlet.ShouldProcess($IPAddress)){
            $output = [IB_DNSPTRRecord]::Create($Gridmaster, $Credential, $PTRDName, $IPAddress, $Comment, $View, $ttl, $use_ttl)
            $output
        }
    }
    END{}
}
<#
.Synopsis
	New-IBDNSZone creates an object of type DNSARecord in the Infoblox database.
.DESCRIPTION
	New-IBDNSZone creates an object of type DNSARecord in the Infoblox database.  If creation is successful an object of type IB_DNSARecord is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER FQDN
	The fully qualified name of the zone to create.  This should be a valid FQDN for the zone that is to be created.
.PARAMETER ZoneFormat
	The format of the zone to be created. The default value is Forward.  Valid Values are:
        â€¢FORWARD
        â€¢IPV4
        â€¢IPV6

.PARAMETER View
	The Infoblox view to create the zone in.  The provided value must match a valid view on the Infoblox.  If no view is provided the default DNS view is used.
.PARAMETER Comment
	Optional comment field for the dns zone.  Can be used for notation and keyword searching by Get- cmdlets.
.EXAMPLE
	New-IBDNSZone -Gridmaster $Gridmaster -Credential $Credential -zone domain.com -zoneformat Forward -comment 'new zone'

	This example creates a forward-lookup dns zone in the default view
.EXAMPLE
	New-IBDNSZone -Gridmaster $Gridmaster -Credential $Credential  -zoneformat IPV4 -fqdn 10.in-addr-arpa

	This example creates a reverse lookup zone for the 10.0.0.0 network in the default dns view
.INPUTS
	System.String
.OUTPUTS
	IB_ZoneAuth
#>
Function New-IBDNSZone {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$FQDN,

        [ValidateSet('Forward','IPv4','IPv6')]
        [String]$ZoneFormat,

        [String]$View,

        [String]$Comment
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    PROCESS{
        If ($pscmdlet.ShouldProcess($fqdn)){
            $output = [IB_ZoneAuth]::Create($Gridmaster, $Credential, $FQDN, $View, $ZoneFormat, $Comment)
            $output
        }
    }
    END{}
}
<#
.Synopsis
	New-IBExtensibleAttributeDefinition creates an extensible attribute definition in the Infoblox database.
.DESCRIPTION
	New-IBExtensibleAttributeDefinition creates an extensible attribute definition in the Infoblox database.  This can be used as a reference for assigning extensible attributes to other objects.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The Name of the new extensible attribute definition.
.PARAMETER Type
    The type definition for the extensible attribute.  This defines the type of data that can be provided as a value when assigning an extensible attribute to an object.
    Valid values are:
        â€¢DATE
        â€¢EMAIL
        â€¢ENUM
        â€¢INTEGER
        â€¢STRING
        â€¢URL
.PARAMETER DefaultValue
    The default value to assign to the extensible attribute if no value is selected.  This applies when assigning an extensible attribute to an object.
.PARAMETER Comment
	Optional comment field for the object.  Can be used for notation and keyword searching by Get- cmdlets.
.EXAMPLE
	New-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -Name Site -Type String -defaultValue CORP

    This example creates an extensible attribute definition for assigned a site attribute to an object.
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ExtAttrsDef
#>
Function New-IBExtensibleAttributeDefinition {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Name,

        [Parameter(Mandatory=$True)]
        [ValidateSet('Date','Email','Enum','Integer','String','URL')]
        [String]$Type,

        [String]$DefaultValue,

        [String]$Comment

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    PROCESS{
        If ($pscmdlet.ShouldProcess($Name)){
            $output = [IB_ExtAttrsDef]::Create($Gridmaster, $Credential, $Name, $Type, $Comment, $DefaultValue)
            $output
        }
    }
    END{}
}
<#
.Synopsis
	New-IBFixedAddress creates an object of type FixedAddress in the Infoblox database.
.DESCRIPTION
	New-IBFixedAddress creates an object of type FixedAddress in the Infoblox database.  If creation is successful an object of type IB_FixedAddress is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The Name of the device to which the IP Address is reserved.
.PARAMETER IPAddress
	The IP Address for the fixedaddress assignment.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER MAC
	The mac address for the fixed address reservation.  Colon separated format of 00:00:00:00:00:00 is required.  If the parameter is left blank or a MAC of 00:00:00:00:00:00 is used, the address is marked as type "reserved" in the infoblox database.  If a non-zero mac address is provided the IP is reserved for the provided MAC, and the MAC must not be assigned to any other IP Address.
.PARAMETER NetworkView
	The Infoblox networkview to create the record in.  The provided value must match a valid view on the Infoblox, and the subnet for the provided IPAddress must exist in the specified view.  If no view is provided the default network view is used.
.PARAMETER Comment
	Optional comment field for the record.  Can be used for notation and keyword searching by Get- cmdlets.
.EXAMPLE
	New-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential Name Server01 -IPAddress 192.168.1.1

		Name        : Server01
		IPAddress   : 192.168.1.1
		Comment     :
		NetworkView : default
		MAC         : 00:00:00:00:00:00
		_ref        : fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:192.168.1.1/default

	description
	-----------
	This example creates an IP reservation for 192.168.1.1 with no comment in the default view
.EXAMPLE
	New-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -Name Server02.domain.com -IPAddress 192.168.1.2 -comment 'Reservation for Server02' -view default -MAC '11:11:11:11:11:11'

		Name      : Server02
		IPAddress : 192.168.1.2
		Comment   : Reservation for Server02
		View      : default
		MAC       : 11:11:11:11:11:11
		_ref      : fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:192.168.1.2/default

	description
	-----------
	This example creates a dhcp reservation for 192.168.1.1 to the machine with MAC address 11:11:11:11:11:11
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_FixedAddress
#>
Function New-IBFixedAddress {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [IPAddress]$IPAddress,

		[ValidatePattern('^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')]
		[String]$MAC = '00:00:00:00:00:00',

        [String]$Name,

        [String]$NetworkView,

        [String]$Comment
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type NetworkView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($NetworkView){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $NetworkView){
                $NetworkViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $NetworkViewList" -ea Stop
            }
        }

    }

    PROCESS{
        If ($pscmdlet.ShouldProcess($IPAddress)){
            $output = [IB_FixedAddress]::Create($Gridmaster, $Credential, $Name, $IPAddress, $Comment, $NetworkView, $MAC)
            $output
        }
    }
    END{}
}
<#
.Synopsis
	New-IBNetwork creates an object of type DNSARecord in the Infoblox database.
.DESCRIPTION
	New-IBNetwork creates an object of type DNSARecord in the Infoblox database.  If creation is successful an object of type IB_DNSARecord is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Network
	The IP address of the network to create in CIDR format
.PARAMETER NetworkView
	The Infoblox network view to create the network in.  The provided value must match a valid view on the Infoblox.  If no view is provided the default network view is used.
.PARAMETER Comment
	Optional comment field for the network.  Can be used for notation and keyword searching by Get- cmdlets.
.EXAMPLE
    New-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -Network '10.0.0.0/8' -networkview default -comment 'new network'
    
    This example creates a new network for 10.0.0.0 in the default view
.INPUTS
	System.String
.OUTPUTS
	IB_Network
#>
Function New-IBNetwork {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateScript({If ($_ -match '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$') {
            $True
        } else {
            Throw "$_ is not a CIDR address"
        }})]
        [String]$Network,

        [String]$NetworkView,

        [String]$Comment
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type NetworkView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    PROCESS{
        If ($pscmdlet.ShouldProcess($Network)){
            $output = [IB_Network]::Create($Gridmaster, $Credential, $Network, $NetworkView, $Comment)
            $output
        }
    }
    END{}
}
<#
.Synopsis
	New-IBView creates a dns or network view in the Infoblox database.
.DESCRIPTION
	New-IBView creates a dns or network view in the Infoblox database.  If creation is successful an object of type IB_View or IB_NetworkView is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER Name
	The Name of the new view.
.PARAMETER Comment
	Optional comment field for the view.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER Type
    Switch parameter to specify whether creating a DNS view or Network view.
.EXAMPLE
	New-IBView -Gridmaster $Gridmaster -Credential $Credential -Name NewView -Comment 'second view' -Type 'DNSView'

    Creates a new dns view with a comment on the infoblox database
.INPUTS
	System.String
.OUTPUTS
	IB_View
    IB_NetworkView
#>
Function New-IBView {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Name,
        
		[Parameter(Mandatory=$True)]
		[ValidateSet('DNSView','NetworkView')]
		[String]$Type,
        
        [String]$Comment
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
        Write-Verbose "$FunctionName`:  Connecting to Infoblox device $gridmaster to retrieve Views"
        Try {
            $IBViews = Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Type DNSView
        } Catch {
            Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop
        }
        If ($View){
            Write-Verbose "$FunctionName`:  Validating View parameter against list from Infoblox device"
            If ($IBViews.name -cnotcontains $View){
                $ViewList = $ibviews.name -join ', '
                write-error "Invalid data for View parameter.  Options are $ViewList" -ea Stop
            }
        }

    }
    PROCESS{
        If ($pscmdlet.ShouldProcess($Name)){
            If ($Type -eq 'DNSView'){
                $output = [IB_View]::Create($Gridmaster, $Credential, $Name, $Comment)
                $output
            } else {
                $output = [IB_NetworkView]::Create($Gridmaster, $Credential, $Name, $Comment)
                $output
            }
        }
    }
    END{}
}
<#
.Synopsis
	Remove-IBDNSARecord removes the specified DNS A record from the Infoblox database.
.DESCRIPTION
	Remove-IBDNSARecord removes the specified DNS A record from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_DNSARecord representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSARecord.
.EXAMPLE
	Remove-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -_Ref record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testrecord.domain.com/default

	This example deletes the DNS A record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -name Testrecord.domain.com | Remove-IBDNSARecord

	This example retrieves the dns record with name testrecord.domain.com, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBDNSARecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [IB_DNSARecord[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
		If ($pscmdlet.ParameterSetName -eq 'byRef'){
            $Record = [IB_DNSARecord]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBDNSARecord
            }
        }else {
			Foreach ($DNSRecord in $Record){
				If ($pscmdlet.ShouldProcess($DNSRecord)) {
					Write-Verbose "$FunctionName`:  Deleting Record $DNSRecord"
					$DNSRecord.Delete()
				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Remove-IBDNSCNameRecord removes the specified DNS CName record from the Infoblox database.
.DESCRIPTION
	Remove-IBDNSCNameRecord removes the specified DNS CName record from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_DNSARecord representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSCNameRecord.
.EXAMPLE
	Remove-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref record:cname/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testalias.domain.com/default

	This example deletes the DNS CName record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -name testalias.domain.com | Remove-IBDNSCNameRecord

	This example retrieves the dns record with name testalias.domain.com, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Canonical 'oldserver.domain.com' -Strict | Remove-IBDNSCNameRecord

	This example retrieves all dns cname records pointing to an old server, and deletes them.
	
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBDNSCNameRecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [IB_DNSCNameRecord[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
            $Record = [IB_DNSCNameRecord]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBDNSCNameRecord
            }
        }else {
			Foreach ($DNSRecord in $Record){
				If ($pscmdlet.ShouldProcess($DNSrecord)) {
					Write-Verbose "$FunctionName`:  Deleting Record $DNSRecord"
					$DNSRecord.Delete()
				}
			}
        }
    }
    END{}
}
<#
.Synopsis
	Remove-IBDNSPTRRecord removes the specified DNS PTR record from the Infoblox database.
.DESCRIPTION
	Remove-IBDNSPTRRecord removes the specified DNS PTR record from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_DNSPTRRecord representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSPTRRecord.
.EXAMPLE
	Remove-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref record:ptr/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:1.1.168.192.in-addr.arpa/default

	This example deletes the DNS PTR record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -PTRDname Testrecord.domain.com | Remove-IBDNSPTRRecord

	This example retrieves the dns record with PTRDName testrecord.domain.com, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBDNSPTRRecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [IB_DNSPTRRecord[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){		
            $Record = [IB_DNSPTRRecord]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBDNSPTRRecord
            }
        }else {
			Foreach ($DNSRecord in $Record){
				If ($pscmdlet.ShouldProcess($DNSrecord)) {
					Write-Verbose "$FunctionName`:  Deleting Record $DNSRecord"
					$DNSRecord.Delete()
				}
			}
        }
    }
    END{}
}
<#
.Synopsis
	Remove-IBNetwork removes the specified dns zone record from the Infoblox database.
.DESCRIPTION
	Remove-IBNetwork removes the specified dns zone record from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type ib_zoneauth representing the record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBNetwork.
.EXAMPLE
	Remove-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -_Ref zone_auth/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:domain.com/default

	This example deletes the dns zone record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -name Server01 | Remove-IBdnszone

	This example retrieves the address reservation for Server01, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBDNSZone{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,

        [Parameter(Mandatory=$True,ParameterSetName='byObject',ValueFromPipeline=$True)]
        [ib_zoneauth[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
            $Record = [ib_zoneauth]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBDNSZone
            }
        }else {
			Foreach ($Item in $Record){
				If ($pscmdlet.ShouldProcess($Item)) {
					Write-Verbose "$FunctionName`:  Deleting Record $Item"
					$Item.Delete()
				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Remove-IBExtensibleAttribute adds or updates an extensible attribute to an existing infoblox record.
.DESCRIPTION
	Removes the specified extensible attribute from the provided Infoblox object.  A valid infoblox object must be provided either through parameter or pipeline.  Pipeline supports multiple objects, to allow adding/updating the extensible attribute on multiple records at once.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the Infoblox object.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_xxx representing the Infoblox object.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSARecord.
.PARAMETER EAName
	The name of the extensible attribute to remove from the provided infoblox object.
.PARAMETER RemoveAll
	Switch parameter to remove all extensible attributes from the provided infoblox object(s).
.PARAMETER Passthru
	Switch parameter to return the provided object(s) with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Remove-IBExtensibleAttribute -gridmaster $gridmaster -credential $credential -_Ref 'record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default' -EAName Site
	
	This example removes the extensible attribute 'site' from the specified infoblox object.
.EXAMPLE
	Get-IBDNSARecord  -gridmaster $gridmaster -credential $credential -_Ref 'record:a/2ifnkqoOKFNOFkldfjqfko3fjksdfjld:testrecord.domain.com/default' | `
		Remove-IBExtensibleAttribute -EAName Site
	
	This example retrieves the DNS record using Get-IBDNSARecord, then passes that object through the pipeline to Remove-IBExtensibleAttribute, which removes the extensible attribute 'Site' from the object.
.EXAMPLE
	Get-IBFixedAddress -gridmaster $gridmaster -credential $credential -ExtAttributeQuery {Site -eq 'OldSite'} | Remove-IBExtensibleAttribute -RemoveAll
	
	This example retrieves all Fixed Address objects with a defined Extensible attribute of 'Site' with value 'OldSite' and removes all extensible attributes defined on the objects.
#>
Function Remove-IBExtensibleAttribute {
    [CmdletBinding(DefaultParameterSetName='byObjectEAName',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ParameterSetName='byRefEAName')]
        [Parameter(Mandatory=$True,ParameterSetName='byRefAll')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ParameterSetName='byRefEAName')]
        [Parameter(Mandatory=$True,ParameterSetName='byRefAll')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ParameterSetName='byRefEAName')]
        [Parameter(Mandatory=$True,ParameterSetName='byRefAll')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObjectEAName')]
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObjectAll')]
        [object[]]$Record,

		[Parameter(Mandatory=$True, ParameterSetName='byRefEAName')]
		[Parameter(Mandatory=$True, ParameterSetName='byObjectEAName')]
		[String]$EAName,

		[Parameter(Mandatory=$True, ParameterSetName='byRefAll')]
		[Parameter(Mandatory=$True, ParameterSetName='byObjectAll')]
		[Switch]$RemoveAll,

		[Switch]$Passthru
	)
	BEGIN{        
		$FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
		write-verbose "$FunctionName`:  ParameterSetName=$($pscmdlet.ParameterSetName)"
	}
    PROCESS{
        If ($pscmdlet.ParameterSetName -eq "byRefEAName"){
			Write-Verbose "$FunctionName`:  Refstring passed, querying infoblox for record"
			$Record = Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref $_Ref
            If ($Record){
				Write-Verbose "$FunctionName`: object found, passing to cmdlet through pipeline"
                $Record | Remove-IBExtensibleAttribute -EAName $EAName -passthru:$Passthru
            }	
        } elseif($pscmdlet.ParameterSetName -eq "byRefAll"){
			Write-Verbose "$FunctionName`:  Refstring passed, querying infoblox for record"
			$Record = Get-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_Ref $_Ref
            If ($Record){
				Write-Verbose "$FunctionName`: object found, passing to cmdlet through pipeline"
                $Record | Remove-IBExtensibleAttribute -RemoveAll:$RemoveAll -passthru:$Passthru
            }	
		} else {
			Foreach ($Item in $Record){
				If ($RemoveAll){
					write-verbose "$FunctionName`:  Removeall switch specified, removing all extensible attributes from $item"
					foreach ($EAName in $Item.extattrib.Name){
						If ($pscmdlet.ShouldProcess($Item,"Remove EA $EAName")) {
							write-verbose "$FunctionName`:  Removing EA $EAName from $item"
							$Item.RemoveExtAttrib($EAName)
						}
					}
				} else {
					If ($pscmdlet.ShouldProcess($Item,"Remove EA $EAName")) {
						write-verbose "$FunctionName`:  Removing EA $EAName from $item"
						$Item.RemoveExtAttrib($EAName)
					}
				}
				If ($Passthru) {
					Write-Verbose "$FunctionName`:  Passthru specified, returning dns object as output"
					return $Item
				}
			}
		}
	}
	END{}
}
<#
.Synopsis
	Remove-IBExtensibleAttributeDefinition removes the specified extensible attribute definition from the Infoblox database.
.DESCRIPTION
	Remove-IBExtensibleAttributeDefinition removes the specified extensible attribute definition from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the record.  String is in format <recordtype>/<uniqueString>:<Name>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_ExtAttrsDef representing the record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBExtensibleAttributeDefinition.
.EXAMPLE
	Remove-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -_Ref extensibleattributedev/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:EA2

	This example deletes the extensible attribute definition with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBExtensibleAttributeDefinition -Gridmaster $Gridmaster -Credential $Credential -name EA2 | Remove-IBExtensibleAttributeDefinition

	This example retrieves the extensible attribute definition with name EA2, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBExtensibleAttributeDefinition{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,

        [Parameter(Mandatory=$True,ParameterSetName='byObject',ValueFromPipeline=$True)]
        [IB_ExtAttrsDef[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
            $Record = [IB_ExtAttrsDef]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBExtensibleAttributeDefinition
            }
        }else {
			Foreach ($Item in $Record){
				If ($pscmdlet.ShouldProcess($Item)) {
					Write-Verbose "$FunctionName`:  Deleting Record $Item"
					$Item.Delete()
				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Remove-IBFixedAddress removes the specified fixed Address record from the Infoblox database.
.DESCRIPTION
	Remove-IBFixedAddress removes the specified fixed address record from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_FixedAddress representing the record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBFixedAddress.
.EXAMPLE
	Remove-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -_Ref fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:192.168.1.1/default

	This example deletes the fixed address record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -name Server01 | Remove-IBFixedAddress

	This example retrieves the address reservation for Server01, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBFixedAddress{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,

        [Parameter(Mandatory=$True,ParameterSetName='byObject',ValueFromPipeline=$True)]
        [IB_FixedAddress[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
            $Record = [IB_FixedAddress]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBFixedAddress
            }
        }else {
			Foreach ($Item in $Record){
				If ($pscmdlet.ShouldProcess($Item)) {
					Write-Verbose "$FunctionName`:  Deleting Record $Item"
					$Item.Delete()
				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Remove-IBNetwork removes the specified fixed Address record from the Infoblox database.
.DESCRIPTION
	Remove-IBNetwork removes the specified fixed address record from the Infoblox database.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_Network representing the record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBNetwork.
.EXAMPLE
	Remove-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -_Ref Network/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:192.168.1.1/default

	This example deletes the fixed address record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBNetwork -Gridmaster $Gridmaster -Credential $Credential -name Server01 | Remove-IBNetwork

	This example retrieves the address reservation for Server01, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBNetwork{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,

        [Parameter(Mandatory=$True,ParameterSetName='byObject',ValueFromPipeline=$True)]
        [IB_Network[]]$Record
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
            $Record = [IB_Network]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Remove-IBNetwork
            }
        }else {
			Foreach ($Item in $Record){
				If ($pscmdlet.ShouldProcess($Item)) {
					Write-Verbose "$FunctionName`:  Deleting Record $Item"
					$Item.Delete()
				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Remove-IBRecord removes the specified record from the Infoblox database.
.DESCRIPTION
	Remove-IBRecord removes the specified record from the Infoblox database.  This is a generalized version of the Remove-IBDNSARecord, Remove-IBDNSCNameRecord, etc.  If deletion is successful the reference string of the deleted record is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Remove-IBRecord -Gridmaster $Gridmaster -Credential $Credential -_ref fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:192.168.1.1/default

	This example deletes the fixed address record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -name Server01 | Remove-IBRecord

	This example retrieves the address reservation for Server01, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.EXAMPLE
	Remove-DNSInfobloxRecrd -Gridmaster $Gridmaster -Credential $Credential -_Ref record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testrecord.domain.com/default

	This example deletes the DNS A record with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -name Testrecord.domain.com | Remove-IBRecord

	This example retrieves the dns record with name testrecord.domain.com, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBRecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [ValidateNotNullorEmpty()]
        [String]$_Ref
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
		$Record = [IB_ReferenceObject]::Get($Gridmaster,$Credential,$_Ref)
		If ($Record){
			Write-verbose "$FunctionName`:  Record $_ref found, proceeding with deletion"
			If ($pscmdlet.ShouldProcess($Record)) {
				Write-Verbose "$FunctionName`:  Deleting Record $Record"
				$Record.Delete()
			}
		} else {
			Write-Verbose "$FunctionName`:  No record found with reference string $_ref"
		}
	}
    END{}
}
<#
.Synopsis
	Remove-IBNetwork removes the specified view or networkview object from the Infoblox database.
.DESCRIPTION
	Remove-IBNetwork removes the specified view or networkview object from the Infoblox database.  If deletion is successful the reference string of the deleted object is returned.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the object.  String is in format <objecttype>/<uniqueString>:<Name>/<isdefaultBoolean>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.EXAMPLE
	Remove-IBview -Gridmaster $Gridmaster -Credential $Credential -_Ref Networkview/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:view2/false

	This example deletes the networkview object with the specified unique reference string.  If successful, the reference string will be returned as output.
.EXAMPLE
	Get-IBView -Gridmaster $Gridmaster -Credential $Credential -name view2 | Remove-IBView

	This example retrieves the dns view named view2, and deletes it from the infoblox database.  If successful, the reference string will be returned as output.
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_ReferenceObject
#>
Function Remove-IBView{
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [ValidateNotNullorEmpty()]
        [String]$_Ref

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
   }

    PROCESS{
        Try {
            $object = [IB_View]::Get($gridmaster,$Credential,$_ref)
        } Catch {
                write-verbose "No object of type IB_View found with reference string $_ref.  Searching IB_NetworkView types"
        }
        If (! $object){
            Try {
                [IB_NetworkView]::Get($gridmaster,$Credential,$_ref)
            }Catch{
                write-verbose "No object of type IB_NetworkView found with reference string $_ref"        
            }
        }
        If ($object){
            If ($pscmdlet.shouldProcess($object)){
                Write-Verbose "$FunctionName`:  Deleting object $object"
                $object.Delete()
            }
        } else {
            Write-error "No object found with reference string $_ref"
            return
        }
	}
    END{}
}
<#
.Synopsis
	Set-IBDNSARecord modifies properties of an existing DNS A Record in the Infoblox database.
.DESCRIPTION
	Set-IBDNSARecord modifies properties of an existing DNS A Record in the Infoblox database.  Valid IB_DNSARecord objects can be passed through the pipeline for modification.  A valid reference string can also be specified.  On a successful edit no value is returned unless the -Passthru switch is used.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_DNSARecord representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSARecord.
.PARAMETER IPAddress
	The IP Address to set on the provided dns record.  Standard IPv4 notation applies, and a string value must be castable to an IPAddress object.
.PARAMETER Comment
	The comment to set on the provided dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER TTL
	The record-specific TTL to set on the provided dns record.  If the record is currently inheriting the TTL from the Grid, setting this value will also set the record to use the record-specific TTL
.PARAMETER ClearTTL
	Switch parameter to remove any record-specific TTL and set the record to inherit from the Grid TTL
.PARAMETER Passthru
	Switch parameter to return an IB_DNSARecord object with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSARecord -comment 'new comment'
	
	This example retrieves all dns records with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -Name testrecord.domain.com | Set-IBDNSARecord -IPAddress 192.168.1.2 -comment 'new comment' -passthru

		Name      : testrecord.domain.com
		IPAddress : 192.168.1.1
		Comment   : new comment
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testrecord.domain.com/default

	description
	-----------
	This example modifes the IPAddress and comment on the provided record and outputs the updated record definition
.EXAMPLE
	Set-IBDNSARecord -Gridmaster $Gridmaster -Credential $Credential -_ref record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:testrecord2.domain.com/default -ClearTTL -Passthru

		Name      : testrecord2.domain.com
		IPAddress : 192.168.1.2
		Comment   : new record
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:a/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:testrecord2.domain.com/default

	description
	-----------
	This example finds the record based on the provided ref string and clears the record-specific TTL
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSARecord
#>
Function Set-IBDNSARecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [IB_DNSARecord[]]$Record,
        
        [IPAddress]$IPAddress = '0.0.0.0',

        [String]$Comment = "unspecified",

        [uint32]$TTL = 4294967295,

        [Switch]$ClearTTL,

		[Switch]$Passthru

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
   }

    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
			
            $Record = [IB_DNSARecord]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Set-IBDNSARecord -IPAddress $IPAddress -Comment $Comment -TTL $TTL -ClearTTL:$ClearTTL -Passthru:$Passthru
            }
			
        }else {
			Foreach ($DNSRecord in $Record){
				If ($pscmdlet.ShouldProcess($DNSRecord)) {
					If ($IPAddress -ne '0.0.0.0'){
						write-verbose "$FunctionName`:  Setting IPAddress to $IPAddress"
						$DNSRecord.Set($IPAddress, $DNSRecord.Comment, $DNSRecord.TTL, $DNSRecord.Use_TTL)
					}
					If ($Comment -ne "unspecified"){
						write-verbose "$FunctionName`:  Setting comment to $comment"
						$DNSRecord.Set($DNSRecord.IPAddress, $Comment, $DNSRecord.TTL, $DNSRecord.Use_TTL)
					}
					If ($ClearTTL){
						write-verbose "$FunctionName`:  Setting TTL to 0 and Use_TTL to false"
						$DNSRecord.Set($DNSRecord.IPAddress, $DNSRecord.comment, $Null, $False)
					} elseIf ($TTL -ne 4294967295){
						write-verbose "$FunctionName`:  Setting TTL to $TTL and Use_TTL to True"
						$DNSRecord.Set($DNSRecord.IPAddress, $DNSRecord.Comment, $TTL, $True)
					}
					If ($Passthru) {
						Write-Verbose "$FunctionName`:  Passthru specified, returning dns object as output"
						return $DNSRecord
					}

				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Set-IBDNSCNameRecord modifies properties of an existing DNS CName Record in the Infoblox database.
.DESCRIPTION
	Set-IBDNSCNameRecord modifies properties of an existing DNS CName Record in the Infoblox database.  Valid IB_DNSCNameRecord objects can be passed through the pipeline for modification.  A valid reference string can also be specified.  On a successful edit no value is returned unless the -Passthru switch is used.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_DNSCNameRecord representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSCNameRecord.
.PARAMETER Canonical
	The canonical name or alias target to set on the provided dns record.
.PARAMETER Comment
	The comment to set on the provided dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER TTL
	The record-specific TTL to set on the provided dns record.  If the record is currently inheriting the TTL from the Grid, setting this value will also set the record to use the record-specific TTL
.PARAMETER ClearTTL
	Switch parameter to remove any record-specific TTL and set the record to inherit from the Grid TTL
.PARAMETER Passthru
	Switch parameter to return an IB_DNSCNameRecord object with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSCNameRecord -comment 'new comment'
	
	This example retrieves all dns records with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -Name testalias.domain.com | Set-IBDNSCNameRecord -Canonical testrecord2.domain.com -comment 'new comment' -passthru

		Name      : testalias.domain.com
		Canonical : testrecord2.domain.com
		Comment   : new comment
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:cname/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:testrecord.domain.com/default

	description
	-----------
	This example modifes the IPAddress and comment on the provided record and outputs the updated record definition
.EXAMPLE
	Set-IBDNSCNameRecord -Gridmaster $Gridmaster -Credential $Credential -_ref record:cname/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:testrecord2.domain.com/default -ClearTTL -Passthru

		Name      : testalias2.domain.com
		Canonical : testrecord2.domain.com
		Comment   : new record
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:cname/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:testrecord2.domain.com/default

	description
	-----------
	This example finds the record based on the provided ref string and clears the record-specific TTL
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSCNameRecord
#>
Function Set-IBDNSCNameRecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [IB_DNSCNameRecord[]]$Record,
        
        [String]$Canonical = 'unspecified',

        [String]$Comment = 'unspecified',

        [uint32]$TTL = 4294967295,

        [Switch]$ClearTTL,

		[Switch]$Passthru

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
    }


    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
			
            $Record = [IB_DNSCNameRecord]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Set-IBDNSCNameRecord -Canonical $Canonical -Comment $Comment -TTL $TTL -ClearTTL:$ClearTTL -Passthru:$Passthru
            }
			
        }else {
			Foreach ($DNSRecord in $Record){
				If ($pscmdlet.ShouldProcess($DNSrecord)) {
					If ($Canonical -ne 'unspecified'){
						Write-Verbose "$FunctionName`:  Setting canonical to $canonical"
						$DNSRecord.Set($canonical, $DNSRecord.Comment, $DNSRecord.TTL, $DNSrecord.Use_TTL)
					}
					If ($Comment -ne "unspecified"){
						write-verbose "$FunctionName`:  Setting comment to $comment"
						$DNSRecord.Set($DNSRecord.canonical, $Comment, $DNSRecord.TTL, $DNSRecord.Use_TTL)
					}
					If ($ClearTTL){
						write-verbose "$FunctionName`:  Setting TTL to 0 and Use_TTL to false"
						$DNSRecord.Set($DNSrecord.canonical, $DNSrecord.comment, $Null, $False)
					} elseIf ($TTL -ne 4294967295){
						write-verbose "$FunctionName`:  Setting TTL to $TTL and Use_TTL to True"
						$DNSrecord.Set($DNSrecord.canonical, $DNSrecord.Comment, $TTL, $True)
					}
					If ($Passthru) {
						Write-Verbose "$FunctionName`:  Passthru specified, returning dns object as output"
						return $DNSRecord
					}
				}
			}
        }
    }
    END{}
}
<#
.Synopsis
	Set-IBDNSPTRRecord modifies properties of an existing DNS PTR Record in the Infoblox database.
.DESCRIPTION
	Set-IBDNSPTRRecord modifies properties of an existing DNS PTR Record in the Infoblox database.  Valid IB_DNSPTRRecord objects can be passed through the pipeline for modification.  A valid reference string can also be specified.  On a successful edit no value is returned unless the -Passthru switch is used.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_DNSPTRRecord representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBDNSPTRRecord.
.PARAMETER PTRDName
	The resolvable hostname to set on the provided dns record.	
.PARAMETER Comment
	The comment to set on the provided dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER TTL
	The record-specific TTL to set on the provided dns record.  If the record is currently inheriting the TTL from the Grid, setting this value will also set the record to use the record-specific TTL
.PARAMETER ClearTTL
	Switch parameter to remove any record-specific TTL and set the record to inherit from the Grid TTL
.PARAMETER Passthru
	Switch parameter to return an IB_DNSPTRRecord object with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBDNSPTRRecord -comment 'new comment'
	
	This example retrieves all dns ptr records with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -PTRDName testrecord.domain.com | Set-IBDNSPTRRecord -PTRDName testrecord2.domain.com -comment 'new comment' -passthru

		Name      : testrecord2.domain.com
		IPAddress : 192.168.1.1
		Comment   : new comment
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:ptr/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:1.1.168.192.in-addr.arpa/default

	description
	-----------
	This example modifes the PTRDName and comment on the provided record and outputs the updated record definition
.EXAMPLE
	Set-IBDNSPTRRecord -Gridmaster $Gridmaster -Credential $Credential -_ref record:ptr/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:2.1.168.192.in-addr.arpa/default -ClearTTL -Passthru

		Name      : testrecord2.domain.com
		IPAddress : 192.168.1.2
		Comment   : new record
		View      : default
		TTL       : 0
		Use_TTL   : False
		_ref      : record:ptr/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:2.1.168.192.in-addr.arpa/default

	description
	-----------
	This example finds the record based on the provided ref string and clears the record-specific TTL
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_DNSPTRRecord
#>
Function Set-IBDNSPTRRecord{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ParameterSetName='byObject')]
        [IB_DNSPTRRecord[]]$Record,
        
        [String]$PTRDName = 'unspecified',

        [String]$Comment = 'unspecified',

        [uint32]$TTL = 4294967295,

        [Switch]$ClearTTL,

		[Switch]$Passthru

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
    }


    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
			
            $Record = [IB_DNSPTRRecord]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Set-IBDNSPTRRecord -PTRDName $PTRDName -Comment $Comment -TTL $TTL -ClearTTL:$ClearTTL -Passthru:$Passthru
            }
			
        }else {
			Foreach ($DNSRecord in $Record){
				If ($pscmdlet.ShouldProcess($DNSrecord)) {
					If ($PTRDName -ne 'unspecified'){
						Write-Verbose "$FunctionName`:  Setting PTRDName to $PTRDName"
						$DNSRecord.Set($PTRDName, $DNSRecord.Comment, $DNSRecord.TTL, $DNSrecord.Use_TTL)
					}
					If ($Comment -ne "unspecified"){
						write-verbose "$FunctionName`:  Setting comment to $comment"
						$DNSRecord.Set($DNSRecord.PTRDName, $Comment, $DNSRecord.TTL, $DNSRecord.Use_TTL)
					}
					If ($ClearTTL){
						write-verbose "$FunctionName`:  Setting TTL to 0 and Use_TTL to false"
						$DNSRecord.Set($DNSrecord.PTRDName, $DNSrecord.comment, $Null, $False)
					} elseIf ($TTL -ne 4294967295){
						write-verbose "$FunctionName`:  Setting TTL to $TTL and Use_TTL to True"
						$DNSrecord.Set($DNSrecord.PTRDName, $DNSrecord.Comment, $TTL, $True)
					}
					If ($Passthru) {
						Write-Verbose "$FunctionName`:  Passthru specified, returning dns object as output"
						return $DNSRecord
					}
				}
			}
        }
    }
    END{}
}
<#
.Synopsis
	Set-IBFixedAddress modifies properties of an existing fixed address in the Infoblox database.
.DESCRIPTION
	Set-IBFixedAddress modifies properties of an existing fixed address in the Infoblox database.  Valid IB_FixedAddress objects can be passed through the pipeline for modification.  A valid reference string can also be specified.  On a successful edit no value is returned unless the -Passthru switch is used.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the DNS record.  String is in format <recordtype>/<uniqueString>:<Name>/<view>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_FixedAddress representing the DNS record.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBFixedAddress.
.PARAMETER Name
	The hostname to set on the provided dns record.	
.PARAMETER Comment
	The comment to set on the provided dns record.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER MAC
	The MAC address to set on the record.  Colon separated format of 00:00:00:00:00:00 is required.
.PARAMETER Passthru
	Switch parameter to return an IB_FixedAddress object with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBFixedAddress -comment 'new comment'
	
	This example retrieves all fixed addresses with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -Name testrecord.domain.com | Set-IBFixedAddress -Name testrecord2.domain.com -comment 'new comment' -passthru

		Name      : testrecord2.domain.com
		IPAddress : 192.168.1.1
		Comment   : new comment
		MAC       : 00:00:00:00:00:00
		View      : default
		_ref      : fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:192.168.1.1/default

	description
	-----------
	This example modifes the PTRDName and comment on the provided record and outputs the updated record definition
.EXAMPLE
	Set-IBFixedAddress -Gridmaster $Gridmaster -Credential $Credential -_ref fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:192.168.1.2/default -MAC '11:11:11:11:11:11' -Passthru

		Name      : testrecord2.domain.com
		IPAddress : 192.168.1.2
		Comment   : new record
		MAC       : 11:11:11:11:11:11
		View      : default
		_ref      : fixedaddress/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:192.168.1.2/default

	description
	-----------
	This example finds the record based on the provided ref string and set the MAC address on the record
.INPUTS
	System.Net.IPAddress[]
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_FixedAddress
#>
Function Set-IBFixedAddress{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
        [String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,

        [Parameter(Mandatory=$True,ParameterSetName='byObject',ValueFromPipeline=$True)]
        [IB_FixedAddress[]]$Record,

        [String]$Name = "unspecified",

        [String]$Comment = "unspecified",
		
		[ValidatePattern('^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')]
		[String]$MAC = '99:99:99:99:99:99',

		[Switch]$Passthru
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
        write-verbose "$FunctionName`:  Beginning Function"
    }
    PROCESS{
            If ($pscmdlet.ParameterSetName -eq 'byRef'){
			
            $Record = [IB_FixedAddress]::Get($Gridmaster,$Credential,$_Ref)
            If ($Record){
                $Record | Set-IBFixedAddress -Name $Name -Comment $Comment -mac $MAC -Passthru:$Passthru
            }
			
        }else {
			Foreach ($Item in $Record){
				If ($pscmdlet.ShouldProcess($Item)) {
					If ($Name -ne 'unspecified'){
						write-verbose "$FunctionName`:  Setting Name to $Name"
						$Item.Set($Name, $Item.Comment, $Item.MAC)
					}
					If ($Comment -ne 'unspecified'){
						write-verbose "$FunctionName`:  Setting comment to $comment"
						$Item.Set($Item.Name, $Comment, $Item.MAC)
					}
					If ($MAC -ne '99:99:99:99:99:99'){
						write-verbose "$FunctionName`:  Setting MAC to $MAC"
						$Item.Set($Item.Name, $Item.Comment, $MAC)
					}
					If ($Passthru) {
						Write-Verbose "$FunctionName`:  Passthru specified, returning object as output"
						return $Item
					}
				}
			}
		}
	}
    END{}
}
<#
.Synopsis
	Set-IBView modifies properties of an existing View or NetworkView object in the Infoblox database.
.DESCRIPTION
	Set-IBView modifies properties of an existing View or NetworkView object in the Infoblox database.  Valid IB_View or IB_NetworkView objects can be passed through the pipeline for modification.  A valid reference string can also be specified.  On a successful edit no value is returned unless the -Passthru switch is used.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.PARAMETER Credential
	Powershell credential object for use in authentication to the specified gridmaster.  This username/password combination needs access to the WAPI interface.
.PARAMETER _Ref
	The unique reference string representing the View or NetworkView object.  String is in format <recordtype>/<uniqueString>:<Name>/<defaultbool>.  Value is assigned by the Infoblox appliance and returned with and find- or get- command.
.PARAMETER Record
	An object of type IB_View or IB_NetworkView representing the View or NetworkView object.  This parameter is typically for passing an object in from the pipeline, likely from Get-IBView.
.PARAMETER Name
	The name to set on the provided View or NetworkView object.
.PARAMETER Comment
	The comment to set on the provided View or NetworkView object.  Can be used for notation and keyword searching by Get- cmdlets.
.PARAMETER Passthru
	Switch parameter to return an IB_View or IB_NetworkView object with the new values after updating the Infoblox.  The default behavior is to return nothing on successful record edit.
.EXAMPLE
	Get-IBView -Gridmaster $Gridmaster -Credential $Credential -comment 'old comment' -Strict | Set-IBView -comment 'new comment'
	
	This example retrieves all View or NetworkView objects with a comment of 'old comment' and replaces it with 'new comment'
.EXAMPLE
	Get-IBView -Gridmaster $Gridmaster -Credential $Credential -Name view2 | Set-IBView -name view3 -comment 'new comment' -passthru

		Name      : view3
		Comment   : new comment
		is_default: false
		_ref      : view/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkYWR1dGwwMWNvcnAsMTAuOTYuMTA1LjE5MQ:view3/false

	description
	-----------
	This example modifes the name and comment on the provided record and outputs the updated record definition
.EXAMPLE
	Set-IBView -Gridmaster $Gridmaster -Credential $Credential -_ref networkview/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:networkview2/false -Passthru -comment $False

		Name      : networkview2
		Comment   : 
		is_default: False
		_ref      : networkview/ZG5zLmJpbmRfYSQuX2RlZmF1bHQuY29tLmVwcm9kLHBkZGNlcGQwMWhvdW1yaWIsMTAuNzUuMTA4LjE4MA:networkview2/false

	description
	-----------
	This example finds the record based on the provided ref string and clears the comment
.INPUTS
	System.String
	IB_ReferenceObject
.OUTPUTS
	IB_View
    IB_NetworkView
#>
Function Set-IBView{
    [CmdletBinding(DefaultParameterSetName='byObject',SupportsShouldProcess=$True,ConfirmImpact="High")]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateScript({If($_){Test-IBGridmaster $_ -quiet}})]
		[String]$Gridmaster,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential,

        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName='byRef')]
        [ValidateNotNullorEmpty()]
        [String]$_Ref,
        
        [Parameter(Mandatory=$True,ParameterSetName='byObject',ValueFromPipeline=$True)]
        [ValidateScript({$_.GetType().Name -eq 'IB_View' -or $_.GetType().name -eq 'IB_NetworkView'})]
        [object[]]$Record,
        
        [String]$Name = 'unspecified',

        [String]$Comment = 'unspecified',

		[Switch]$Passthru

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
		write-verbose "$FunctionName`:  Beginning Function"
   }

    PROCESS{
        If ($pscmdlet.ParameterSetName -eq 'byRef'){
            If ($_Ref -like "view/*"){
                $Record = [IB_View]::Get($Gridmaster,$Credential,$_Ref)
            } elseif ($_Ref -like "networkview/*") {
                $Record = [IB_NetworkView]::Get($Gridmaster,$Credential,$_Ref)
            }
                If ($Record){
                    $Record | Set-IBView -name $Name -Comment $Comment -Passthru:$Passthru
                }
        } else {
            foreach ($item in $Record){
                If ($pscmdlet.shouldProcess($item)){
                    If ($comment -ne 'unspecified'){
                        write-verbose "$FunctionName`:  Setting comment to $comment"
                        $item.Set($item.Name, $Comment)
                    }
                    If ($Name -ne 'unspecified'){
                        write-verbose "$FunctionName`:  Setting name to $Name"
                        $item.Set($Name, $item.comment)
                    }
                    If ($Passthru) {
                        Write-Verbose "$FunctionName`:  Passthru specified, returning object as output"
                        return $item
                    }
                }
            }
        }
	}
    END{}
}
<#
.Synopsis
    Tests for connection to accessible Infoblox Gridmaster.
.DESCRIPTION
    Tests for connection to accessible Infoblox Gridmaster.  Connects to provided gridmaster FQDN over SSL and verifies gridmaster functionality.
.PARAMETER Gridmaster
	The fully qualified domain name of the Infoblox gridmaster.  SSL is used to connect to this device, so a valid and trusted certificate must exist for this FQDN.
.Parameter Quiet
    Switch parameter to specify whether error output should be provided with more detail about the connection errors.
.EXAMPLE
    Test-IBGridmaster -Gridmaster testGM.domain.com

	This example tests the connection to testGM.domain.com and returns a True or False value based on availability.
.INPUTS
	System.String
.OUTPUTS
    Bool
#>
Function Test-IBGridmaster {
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Gridmaster,
        
        [Switch]$Quiet
    )
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    write-verbose "$FunctionName`:  Beginning Function"
		Try {
            write-verbose "$FunctionName`:  Attempting connection to https://$gridmaster/wapidoc/"
            $data = invoke-webrequest -uri "https://$gridmaster/wapidoc/" -UseBasicParsing
            If ($Data){
                If ($Data.rawcontent -like "*Infoblox WAPI Documentation*"){
                    return $True
                } else {
                    If (! $Quiet){write-error "invalid data returned from $Gridmaster.  Not a valid Infoblox device"}
                    return $False
                }
            } else {
                if (! $Quiet){write-error "No data returned from $gridmaster.  Not a valid Infoblox device"}
                return $False
            }
		} Catch {
			if (! $Quiet){Write-error "Unable to connect to Infoblox device $gridmaster.  Error code:  $($_.exception)" -ea Stop}
            return $False
		}
}
